module ErpApp
  module Desktop
    module SystemManagement
      class TypesController < ::ErpApp::Desktop::BaseController

        def index
          types = []
          query_filter = params[:query_filter].blank? ? nil : params[:query_filter]

          unless query_filter.nil?
            query_filter = JSON.parse(query_filter)
            query_filter.symbolize_keys!
          end

          if params[:klass].present? and params[:parent_id].present?
            compass_ae_type = params[:klass].constantize.find(params[:parent_id])

            if query_filter
              compass_ae_type.descendants.where("description ILIKE '%#{query_filter[:keyword]}%' OR internal_identifier ILIKE '%#{query_filter[:keyword]}%'").each do |descendant|
                descendant.self_and_ancestors.where("parent_id = #{compass_ae_type.id}").each do |record|
                  unless types.any? {|t| t[:server_id] == record.id}
                    types.push({
                                     server_id: record.id,
                                     description: record.description,
                                     internal_identifier: record.internal_identifier,
                                     klass: params[:klass]
                                 })
                  end
                end
              end
            else
              compass_ae_type.children.each do |compass_ae_type_child|
                types.push({
                               server_id: compass_ae_type_child.id,
                               description: compass_ae_type_child.description,
                               internal_identifier: compass_ae_type_child.internal_identifier,
                               klass: params[:klass]
                           })
              end
            end
          elsif params[:klass].present?
            compass_ae_type = params[:klass].constantize

            if query_filter
              query_results = compass_ae_type.where("description ILIKE '%#{query_filter[:keyword]}%' OR internal_identifier ILIKE '%#{query_filter[:keyword]}%'").all
              if compass_ae_type.respond_to?(:roots)
                root_ids = query_results.collect{|type| type.root.id}.uniq
              else
                root_ids = query_results.collect{|type| type.id}.uniq
              end

              unless root_ids.empty?
                compass_ae_type.where("id in (#{root_ids.join(',')})").each do |record|
                  types.push({
                                 server_id: record.id,
                                 description: record.description,
                                 internal_identifier: record.internal_identifier,
                                 klass: params[:klass]
                             })
                end
              end
            else
              if compass_ae_type.respond_to?(:roots)
                compass_ae_type.roots.each do |record|
                  types.push({
                                 server_id: record.id,
                                 description: record.description,
                                 internal_identifier: record.internal_identifier,
                                 klass: params[:klass]
                             })
                end
              else
                compass_ae_type.all.each do |record|
                  types.push({
                                 server_id: record.id,
                                 description: record.description,
                                 internal_identifier: record.internal_identifier,
                                 klass: params[:klass],
                                 leaf: true
                             })
                end
              end
            end
          else
            compass_ae_types = ErpBaseErpSvcs::Extensions::ActiveRecord::ActsAsErpType.models

            if query_filter
              compass_ae_types.each do |compass_ae_type|
                query_results = compass_ae_type.constantize.where("description ILIKE '%#{query_filter[:keyword]}%' OR internal_identifier ILIKE '%#{query_filter[:keyword]}%'").all
                unless query_results.empty?
                  types.push({
                    description: compass_ae_type.to_s,
                    klass: compass_ae_type.to_s,
                    leaf: false
                  })

                end
              end
            else
              types = compass_ae_types.collect do |compass_ae_type|
                {
                    description: compass_ae_type.to_s,
                    klass: compass_ae_type.to_s,
                    leaf: false
               }
              end
            end

            types = types.sort_by{|t| t[:description]}
          end

          render json: {success: true, types: types}
        end

        def create
          begin
            ActiveRecord::Base.transaction do
              record = params[:klass].constantize.new(description: params[:description].strip,
                                                      internal_identifier: params[:internal_identifier].strip)
              record.save!

              if params[:parent_id].present?
                record.move_to_child_of(params[:klass].constantize.find(params[:parent_id]))
              end

              render json: {success: true, type: {
                         server_id: record.id,
                         description: record.description,
                         internal_identifier: record.internal_identifier,
                         klass: params[:klass]
                     }}
            end
          rescue => ex
            Rails.logger.error ex.message
            Rails.logger.error ex.backtrace.join("\n")

            # email error
            ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

            render json: {success: false, message: ex.message}
          end
        end

        def update
          record = params[:klass].constantize.find(params[:id])

          begin
            ActiveRecord::Base.transaction do
              record.description = params[:description].strip
              record.internal_identifier = params[:internal_identifier].strip
              record.save!

              render json: {success: true, type: {
                         server_id: record.id,
                         description: record.description,
                         internal_identifier: record.internal_identifier,
                         klass: params[:klass]
                     }}
            end
          rescue => ex
            Rails.logger.error ex.message
            Rails.logger.error ex.backtrace.join("\n")

            # email error
            ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

            render json: {success: false, message: ex.message}
          end
        end

        def destroy
          params[:klass].constantize.find(params[:id]).destroy

          render json: {success: true}
        end

        def reorder
          position = params[:dropped_position]
          klass = params[:klass]
          drag_node = klass.constantize.find(params[:drag_node_id])
          dropped_on_node = klass.constantize.find(params[:dropped_on_node_id])
          reordered = true

          if drag_node.nil? or dropped_on_node.nil?
            reordered = false
          else
            if position == 'before'
              drag_node.move_to_left_of(dropped_on_node)
            elsif position == 'after'
              drag_node.move_to_right_of(dropped_on_node)
            else
              reordered = false
            end
          end

          render json: {success: reordered}
        end

        def export
          begin
            types_hash = []

            if params[:export_all]

              #
              # Export all ERP type data
              #
              erp_types = ErpBaseErpSvcs::Extensions::ActiveRecord::ActsAsErpType.models

              erp_types.each do |erp_type|
                hash = {
                    erp_type: erp_type,
                    data: []
                }

                if erp_type.constantize.respond_to? (:roots)
                  types = erp_type.constantize.roots.all
                else
                  types = erp_type.constantize.all
                end

                types.each do |type|
                  hash[:data].push(build_type_node(type))
                end

                types_hash.push(hash)
              end
            else
              hash = {
                  erp_type: params[:klass],
                  data: []
              }

              #
              # Export specified erp type or record and its children
              #
              if params[:id].nil?
                if params[:klass].constantize.respond_to? (:roots)
                  types = params[:klass].constantize.roots.all
                else
                  types = params[:klass].constantize.all
                end
              else
                types = [params[:klass].constantize.find(params[:id])]
              end

              types.each do |type|
                hash[:data].push(build_type_node(type))
              end

              types_hash.push(hash)
            end

            #
            # Export and create zip file
            #
            tmp_dir = Pathname.new(Rails.root.to_s + "/tmp/erp_types/tmp_#{Time.now.to_i.to_s}/").tap do |dir|
              FileUtils.mkdir_p(dir) unless dir.exist?
            end

            Zip::ZipFile.open(tmp_dir + "ERPTypes.zip", Zip::ZipFile::CREATE) do |zipfile|
              zipfile.get_output_stream("erp_types.yml") { |f| f.puts types_hash.to_yaml }
            end

            zip_path = (tmp_dir + "ERPTypes.zip")

            send_file(zip_path.to_s, :stream => false) rescue raise "Error sending #{zip_path} file"

          rescue => ex
            Rails.logger.error ex.message
            Rails.logger.error ex.backtrace.join("\n")

            # email error
            ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

            raise "Error sending file"
          end
        end

        def import
          begin
            file_path = params[:erp_type_data]
            unless file_path.is_a?(String)
              if file_path.path
                file_path = file_path.path
              else
                file = ActionController::UploadedTempfile.new("uploaded-erp-type").tap do |f|
                  f.puts file_path.read
                  f.original_filename = file_path.original_filename
                  f.read # no idea why we need this here, otherwise the zip can't be opened
                end
                file_path = file.path
              end
            end

            erp_types_hash = nil
            tmp_dir = Pathname.new(Rails.root.to_s + "/tmp/module_templates/tmp_#{Time.now.to_i.to_s}/").tap do |dir|
              FileUtils.mkdir_p(dir) unless dir.exist?
            end

            Zip::ZipFile.open(file_path) do |zip|
              zip.each do |entry|
                f_path = File.join(tmp_dir.to_s, entry.name)
                FileUtils.mkdir_p(File.dirname(f_path))
                zip.extract(entry, f_path) unless File.exist?(f_path)

                next if entry.name =~ /__MACOSX\//
                if entry.name =~ /erp_types.yml/
                  data = ''
                  entry.get_input_stream { |io| data = io.read }
                  data = StringIO.new(data) if data.present?
                  erp_types_hash = YAML.load(data)
                end
              end
            end

            FileUtils.rm_rf(tmp_dir.to_s)

            ActiveRecord::Base.transaction do
              erp_types_hash.each do |erp_type_data|
                erp_type = erp_type_data[:erp_type].constantize
                create_type_records(erp_type_data[:data], erp_type, nil)
              end

              render :json => {success: true}
            end
          rescue StandardError => ex
            Rails.logger.error ex.message
            Rails.logger.error ex.backtrace.join("\n")

            ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

            render :json => {success: false, message: ex.message}
          end
        end

        private

        def create_type_records(data, erp_type, parent=nil)
          unless data.nil?
            data.each do |child|
              if erp_type.iid(child[:internal_identifier]).nil?

                #
                # Check if this model has valid to/from roles that needs to be imported
                #
                if erp_type.column_names.include? "valid_from_role_type_id"
                  to_role_type_id = nil
                  from_role_type_id = nil

                  unless child[:valid_from_role_type_iid].nil?
                    from_role_type = RoleType.iid(child[:valid_from_role_type_iid])

                    if from_role_type.nil?
                      from_role_type = RoleType.create(:description => child[:valid_from_role_type_description], :internal_identifier => child[:valid_from_role_type_iid] )
                    end

                    from_role_type_id = from_role_type.id
                  end

                  unless child[:valid_to_role_type_iid].nil?
                    to_role_type = RoleType.iid(child[:valid_to_role_type_iid])

                    if to_role_type.nil?
                      to_role_type = RoleType.create(:description => child[:valid_to_role_type_description], :internal_identifier => child[:valid_to_role_type_iid] )
                    end

                    to_role_type_id = to_role_type.id
                  end

                  record = erp_type.create(:description => child[:description], :internal_identifier => child[:internal_identifier], :valid_from_role_type_id => from_role_type_id, :valid_to_role_type_id => to_role_type_id)
                else
                  record = erp_type.create(:description => child[:description], :internal_identifier => child[:internal_identifier])
                end
              else
                record = erp_type.iid(child[:internal_identifier])
              end

              unless parent.nil?
                record.move_to_child_of(parent)
              end

              create_type_records(child[:children], erp_type, record)
            end
          end
        end

        def build_type_node(type)

          #
          # Recursively builds data nodes for each erp type record with following attributes
          # {
          #   :internal_identifier => text,
          #   :description => text,
          #   :children => array of child nodes
          # }
          #
          if type.respond_to? :valid_from_role_type_id
            from_role = nil
            to_role = nil

            #
            # Include valid to/from role type data if applicable
            #
            unless type.valid_from_role_type_id.nil?
              from_role = RoleType.find(type.valid_from_role_type_id)
            end
            unless type.valid_to_role_type_id.nil?
              to_role = RoleType.find(type.valid_to_role_type_id)
            end

            node = {
                internal_identifier: type.internal_identifier,
                description: type.description,
                valid_from_role_type_iid: from_role.nil? ? nil : from_role.internal_identifier,
                valid_from_role_type_description: from_role.nil? ? nil : from_role.description,
                valid_to_role_type_iid: to_role.nil? ? nil : to_role.internal_identifier,
                valid_to_role_type_description: to_role.nil? ? nil : to_role.description,
                children: []
            }
          else
            node = type.to_hash(:only => [:internal_identifier,
                                   :description],
                         children: [])
          end

          if !type.respond_to?(:leaf) or type.leaf?
            node = node.except(:children)
          else
            type.children.each do |t|
              node[:children].push(build_type_node(t))
            end
          end

          node
        end

      end #BaseController
    end #SystemManagement
  end #Desktop
end #ErpApp