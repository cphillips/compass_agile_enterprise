require 'yaml'
require 'aws/s3'

module ErpTechSvcs
  module FileSupport
    class S3Manager < Manager
      class << self
        cattr_accessor :s3_connection, :s3_bucket, :tree

        def setup_connection
          @@configuration = YAML::load_file(File.join(Rails.root, 'config', 's3.yml'))[Rails.env]

          # S3 debug logging
          AWS.config(
            :logger => Rails.logger,
            :log_level => :info
          )

          @@s3_connection = AWS::S3.new(
            :access_key_id => @@configuration['access_key_id'],
            :secret_access_key => @@configuration['secret_access_key']
          )

          @@s3_bucket = @@s3_connection.buckets[@@configuration['bucket'].to_sym]
        end

      end

      def buckets
        @@s3_connection.buckets
      end

      def bucket=(name)
        @@s3_bucket = @@s3_connection.buckets[name.to_sym]
      end

      def bucket
        @@s3_bucket
      end

      def root
        ''
      end

      def replace_file(old_path, new_path, contents)
        create_name = File.basename(new_path);
        create_path = new_path.split('/').reverse.drop(1).reverse.join('/')

        create_file(create_path, create_name, contents)
        delete_file(old_path)
      end

      def update_file(path, content)
        file = FileAsset.where(:name => ::File.basename(path)).where(:directory => ::File.dirname(path)).first
        acl = (file.is_secured? ? :private : :public_read) unless file.nil?
        options = (file.nil? ? {} : {:acl => acl, :content_type => file.content_type})
        path = path.sub(%r{^/}, '')
        bucket.objects[path].write(content, options)
      end

      def create_file(path, name, content)
        path = path.sub(%r{^/}, '')
        full_filename = (path.blank? ? name : File.join(path, name))
        bucket.objects[full_filename].write(content, {:acl => :public_read})
      end

      # copy a file
      def copy_file(origination_file, path, name)
        contents = get_contents(origination_file)

        create_file(path, name, contents)
      end

      def create_folder(path, name)
        path = path.sub(%r{^/}, '')
        full_filename = (path.blank? ? name : File.join(path, name))
        folder = full_filename + "/"
        bucket.objects[folder].write('', {:acl => :public_read})
      end

      def save_move(path, new_parent_path)
        result = false
        unless self.exists? path
          message = FILE_DOES_NOT_EXIST
        else
          file = FileAsset.where(:name => ::File.basename(path)).where(:directory => ::File.dirname(path)).first
          acl = (file.is_secured? ? :private : :public_read) unless file.nil?
          options = (file.nil? ? {} : {:acl => acl})
          name = File.basename(path)
          path = path.sub(%r{^/}, '')
          new_path = File.join(new_parent_path, name).sub(%r{^/}, '')
          old_object = bucket.objects[path]
          if new_object = old_object.move_to(new_path, options)
            message = "#{name} was moved to #{new_path} successfully"
            result = true
          else
            message = "Error moving file #{path}"
          end
        end

        return result, message
      end

      def rename_file(path, name)
        result = false
        old_name = File.basename(path)
        path_pieces = path.split('/')
        path_pieces.delete(path_pieces.last)
        path_pieces.push(name)
        new_path = path_pieces.join('/')
        begin
          file = FileAsset.where(:name => ::File.basename(path)).where(:directory => ::File.dirname(path)).first
          acl = (file.is_secured? ? :private : :public_read) unless file.nil?
          options = (file.nil? ? {} : {:acl => acl})
          path = path.sub(%r{^/}, '')
          new_path = new_path.sub(%r{^/}, '')

          old_object = bucket.objects[path]
          if new_object = old_object.move_to(new_path, options)
            message = "#{old_name} was renamed to #{name} successfully"
            result = true
          else
            message = "Error renaming #{old_name}"
          end
        rescue AWS::S3::Errors::NoSuchKey => ex
          message = FILE_FOLDER_DOES_NOT_EXIST
        end

        return result, message
      end

      def set_permissions(path, canned_acl=:public_read)
        path = path.sub(%r{^/}, '')
        bucket.objects[path].acl = canned_acl
      end

      def delete_file(path, options={})
        is_directory = File.extname(path).blank?
        path = path.sub(%r{^/}, '')
        result = false
        message = nil
        begin
          bucket.objects.with_prefix(path).delete_all
          message = "File was deleted successfully"
          result = true
        rescue => ex
          result = false
          message = ex
        end

        return result, message, is_directory
      end

      def exists?(path)
        begin
          path = path.sub(%r{^/}, '')
          return bucket.objects[path].exists?
        rescue AWS::S3::Errors::NoSuchKey
          return false
        end
      end

      def get_contents(path)
        contents = nil
        message = nil

        path = path.sub(%r{^/}, '')
        begin
          object = bucket.objects[path]
          contents = object.read
        rescue AWS::S3::Errors::NoSuchKey => error
          contents = ''
          message = FILE_DOES_NOT_EXIST
        end

        return contents, message
      end

      def build_tree(starting_path, options={})
        node_tree = find_node(starting_path, options)
        node_tree.nil? ? [] : node_tree
      end

      def find_node(path, options={})
        parent = {
          :text => path.split('/').pop,
          :iconCls => "icon-content",
          :leaf => false,
          :id => path,
          :children => []
        }

        #remove proceeding slash for s3
        path.sub!(%r{^/}, '')

        if File.extname(path).blank?
          tree = bucket.as_tree(:prefix => path)

          tree.children.each do |node|
            if node.leaf?
              #ignore current path that comes as leaf from s3
              next if node.key == path + '/'

              leaf_hash = {
                :text => node.key.split('/').pop,
                :downloadPath => "/#{node.key.split('/')[0..-2].join('/')}",
                :id => "/#{node.key}",
                :iconCls => 'icon-document',
                :leaf => true
              }

              if options[:file_asset_holder]
                leaf_hash = apply_file_asset_properties(options[:file_asset_holder], leaf_hash)
              end

              parent[:children] << leaf_hash
            else
              parent[:children] << {
                :iconCls => "icon-content",
                :text => node.prefix.split('/').pop,
                :id => "/#{node.prefix}".chop,
                :leaf => false
              }
            end
          end

        else
          parent[:iconCls] = 'icon-document'
          parent[:leaf] = true
          parent[:downloadPath] = "/#{path.split('/')[0..-2].join('/')}"

          if options[:file_asset_holder]
            parent = apply_file_asset_properties(options[:file_asset_holder], parent)
          end
        end

        # add preceding slash back to parent
        parent[:id] = "/#{parent[:id]}"

        parent
      end

      private

      def apply_file_asset_properties(file_asset_holder, hash)
        files = file_asset_holder.files

        file = files.find { |file| file.directory == hash[:downloadPath] and file.name == hash[:text] }
        unless file.nil?
          hash[:isSecured] = file.is_secured?
          hash[:roles] = file.roles.collect { |r| r.internal_identifier }
          hash[:iconCls] = 'icon-document_lock' if hash[:isSecured]
          hash[:size] = file.data_file_size
          hash[:width] = file.width
          hash[:height] = file.height
          hash[:url] = file.data.url
        end

        hash
      end

    end #S3Manager
  end #FileSupport
end #ErpTechSvcs
