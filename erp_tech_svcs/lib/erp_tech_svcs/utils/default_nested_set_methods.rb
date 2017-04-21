module ErpTechSvcs
  module Utils
    module DefaultNestedSetMethods
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # returns an array of hashes which represent all nodes in nested set order,
        # each of which consists of the node's id, internal identifier and representation
        # if a parent is passed it starts there in the tree
        def to_all_representation(parent=nil, container_arr=[], level=0, ancestors=nil)
          if parent
            parent.children.each do |node|
              container_arr << {id: node.id,
                                description: node.to_representation(level),
                                internal_identifier: node.internal_identifier}

              unless node.leaf?
                to_all_representation(node, container_arr, (level + 1))
              end

            end
          else
            ancestors = (ancestors || self.roots)
            ancestors.each do |root|
              container_arr << {id: root.id,
                                description: root.to_representation(level),
                                internal_identifier: root.internal_identifier}

              to_all_representation(root, container_arr, (level + 1))
            end
          end

          container_arr
        end

        def find_roots
          where("parent_id is null")
        end

        def find_children(parent_id = nil)
          parent_id.to_i == 0 ? self.roots : find(parent_id).children
        end

        # find_by_ancestor_iids
        # allows you to find a nested set element by the internal_identifiers in its ancestry
        # for example, to find a GlAccount whose internal_identifier is “site_4”, and whose parent’s internal_identifier is “nightly_room_charge”
        # and whose grandparent’s internal_identifier is “charge”, you would make this call:
        # gl_account = GlAccount.find_by_iids(['charge', 'nightly_room_charge', "site_4"])
        def find_by_ancestor_iids(iids)
          node = nil

          if iids.is_a? Array
            iids.each do |iid|
              if (iid == iids.first)
                node = where("parent_id is null and internal_identifier = ?", iid).first
              else
                node = where("parent_id = ? and internal_identifier = ?", node.id, iid).first
              end
            end
          end

          node
        end

        # find existing node or create it and return it.  Parent can be passed
        # which will scope this node by the parent
        def find_or_create(iid, description, parent=nil)
          # look for it
          record = if parent
            parent.children.find_by_internal_identifier(iid)
          else
            find_by_internal_identifier(iid)
          end

          unless record
            record = create(description: description, internal_identifier: iid)

            if parent
              record.move_to_child_of(parent)
            end
          end

          record
        end

        # Build a tree based on internal identifiers passed
        #
        # @param [Array] Array of internal identifiers
        # @return [Array] Tree from nodes
        def build_tree_from_nodes(node_iids)
          tree = []

          # first we convert the nodes to a hash based array
          node_iids.each do |node_iid|
            node = self.iid(node_iid)

            tree << node.to_hash({only: [{id: :record_id}, :parent_id, :internal_identifier],
                                  leaf: node.leaf?,
                                  text: node.to_label,
                                  children: []})
          end

          # next we need to build the tree structure based on the nodes
          sorted_tree = tree.dup
          tree.each do |node_hash|
            node = self.find(node_hash[:record_id])

            parent_node = nil
            if node.parent
              parent_node = find_parent_in_tree(sorted_tree, node.parent.id)
            end

            if parent_node
              # add to children of parent
              parent_node[:children] << node_hash

              # remove from updated tree
              sorted_tree.delete_if { |item| node_hash[:record_id] == item[:record_id] }
            end
          end

          sorted_tree
        end

        # Delete nodes from a tree based on passed ids
        #
        # @param [Integer, Array] Either an Id or an array of ids to remove
        # @return [Array] Tree with items removed
        def delete_from_tree(tree, id)
          if id.is_a? Array
            id.each do |_id|
              delete_from_tree(tree, _id)
            end
          else
            tree.each do |node|
              if node[:record_id] == id
                tree.delete(node)
              end

              if node[:children]
                delete_from_tree(node[:children], id)
              end
            end
          end

          tree
        end

        private

        def find_parent_in_tree(tree, id)
          parent = nil

          tree.each do |node|
            if node[:record_id] == id
              parent = node
              break
            end

            if node[:children]
              parent = find_parent_in_tree(node[:children], id)

              if parent
                break
              end
            end
          end

          parent
        end

      end

      def to_label
        description
      end

      def leaf
        children.size == 0
      end

      def to_json_with_leaf(options = {})
        self.to_json_without_leaf(options.merge(:methods => :leaf))
      end

      alias_method_chain :to_json, :leaf

      def to_tree_hash(options={}, context={})
        if options[:child_ids]
          _children = self.children.except(:order).order('description asc').where(id: options[:child_ids])
        else
          _children = self.children.except(:order).order('description asc')
        end

        options = {
          only: [:parent_id, :internal_identifier],
          leaf: self.leaf?,
          text: self.to_label,
          children: _children.collect { |child| child.to_tree_hash(options, context) }
        }.merge(options)

        if self.respond_to?(:to_data_hash)
          parameters = self.method(:to_data_hash).parameters
          if parameters.count > 0 && parameters.first.second == :context
            self.to_hash(options).merge(to_data_hash(context))
          else
            self.to_hash(options).merge(to_data_hash)
          end
        else
          self.to_hash(options)
        end
      end

      def children_to_tree_hash(options={}, context={})
        if options[:child_ids]
          _children = self.children.except(:order).order('description asc').where(id: options[:child_ids])
        else
          _children = self.children.except(:order).order('description asc')
        end

        _children.collect { |child| child.to_tree_hash(options) }
      end

      def to_representation(level)
        # returns a string that consists of 1) a number of dashes equal to
        # the category's level and 2) the category's description attr
        rep = ''

        if level > 0
          level.times { rep << '-' }
          rep += ' '
        end

        rep << description
      end

      def to_record_representation(root = self.class.root)
        # returns a string of category descriptions like
        # 'main_category > sub_category n > ... > this category instance'
        if root?
          description
        else
          crawl_up_from(self, root).split('///').compact.reverse.join(' > ')
        end
      end

      def is_descendant_of?(type)
        type = self.class.iid(type) if (type.is_a? String)
        parent = self.parent

        if type.id == self.id
          result = true
        elsif parent.nil?
          result = false
        elsif parent.id == type.id
          result = true
        else
          result = parent.is_descendant_of? type
        end
        result
      end

      private

      def crawl_up_from(node, to_node = self.class.root)
        unless node.nil?
          # returns a string that is a '///'-separated list of nodes
          # from child node to root
          "#{node.description}///#{crawl_up_from(node.parent, to_node) if node != to_node}"
        end
      end


    end #DefaultNestedSetMethods
  end #Utils
end #ErpTechSvcs
