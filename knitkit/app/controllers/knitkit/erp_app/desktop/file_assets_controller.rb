module Knitkit
  module ErpApp
    module Desktop
      class FileAssetsController < ::ErpApp::Desktop::FileManager::BaseController
        skip_before_filter :verify_authenticity_token, :only => :upload_file
        skip_before_filter :require_login, :only => [:download_file_asset]
        before_filter :set_asset_model
        before_filter :set_root_node

        def base_path
          if @root_node.nil?
            @base_path = nil
          else
            @base_path = File.join(@file_support.root, @root_node)
          end

          @base_path
        end

        def expand_directory
          if @assets_model.nil?
            render :json => []
          else
            path = (params[:node] == ROOT_NODE) ? base_path : params[:node]
            render :json => @file_support.build_tree(path, :file_asset_holder => @assets_model, :preload => true)
          end
        end

        def create_file
          path = params[:path] == 'root_node' ? base_path : params[:path]
          name = params[:name]

          @assets_model.add_file('#Empty File', File.join(path, name))

          render :json => {:success => true, :node => @file_support.find_node(File.join(path, name), :file_asset_holder => @assets_model)}
        end

        def create_folder
          path = (params[:path] == 'root_node') ? base_path : params[:path]
          name = params[:name]

          path = File.join(@file_support.root, path) if path.index(@file_support.root).nil?

          @file_support.create_folder(path, name)

          render :json => {:success => true, :node => @file_support.find_node(File.join(path, name), {keep_full_path: false})}
        end

        def upload_file
          #Website level assets if allowed to be viewed can also be uploaded and deleted so this is only checking for the view capability
          if @context == Website
            capability_type = "view"
            capability_resource = "SiteFileAsset"
          else
            capability_type = "upload"
            capability_resource = "GlobalFileAsset"
          end

          begin
            current_user.with_capability(capability_type, capability_resource) do
              result = {}
              upload_path = params[:directory]
              name = params[:name]
              data = request.raw_post

              begin
                path = (upload_path == 'root_node') ? File.join(base_path, name) : File.join(@file_support.root, upload_path, name)

                @assets_model.add_file(data, path)
                result = {:success => true, :node => @file_support.find_node(path, :file_asset_holder => @assets_model)}
              rescue => ex
                logger.error ex.message
                logger.error ex.backtrace.join("\n")
                result = {:success => false, :error => "Error uploading file."}
              end

              #the awesome uploader widget whats this to mime type text, leave it render :inline
              render :inline => result.to_json
            end
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def replace_file
          begin
            contents, message = @file_support.get_contents(params["replace_file_data"].path)

            new_dir = params["node"].split('/').reverse.drop(1).reverse.join('/')
            new_name = params["replace_file_data"].original_filename

            new_path = File.join(new_dir, new_name)

            file = @assets_model.files.find(:first, :conditions => ['name = ? and directory = ?', ::File.basename(params["node"]), ::File.dirname(params["node"])])
            
            file.replace!(params["node"], new_path, contents)

            render :json => {:success => true, name: params["replace_file_data"].original_filename, path: new_path}
          rescue Exception => ex
            Rails.logger.error(ex.message)
            Rails.logger.error(ex.backtrace.join("\n"))

            # email notification
            ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

            render :json => {:success => false, :error => ex.message}
          end
        end

        def save_move
          messages = []
          result = {}
          path = params[:node]
          new_parent_path = params[:parent_node]
          new_parent_path = @root_node if new_parent_path == ROOT_NODE

          nodes_to_move = (params[:selected_nodes] ? JSON(params[:selected_nodes]) : [params[:node]])
          begin
            nodes_to_move.each do |path|
              if ErpTechSvcs::Config.file_storage == :filesystem and !File.exists?(File.join(@file_support.root, path))
                result = {:success => false, :msg => 'File does not exist.'}
              else
                file = @assets_model.files.find(:first, :conditions => ['name = ? and directory = ?', ::File.basename(path), ::File.dirname(path)])
                result, message = file.move(new_parent_path)
              end
              messages << message
            end
            render :json => {:success => true, :msg => messages.join(',')}
          rescue Exception => e
            render :json => {:success => false, :msg => e.message}
          end
        end

        def delete_file
          messages = []

          if @context == Website
            capability_type = "view"
            capability_resource = "SiteFileAsset"
          else
            capability_type = "delete"
            capability_resource = "GlobalFileAsset"
          end

          nodes_to_delete = (params[:selected_nodes] ? JSON(params[:selected_nodes]) : [params[:node]])

          begin
            result = false
            nodes_to_delete.each do |path|
              current_user.with_capability(capability_type, capability_resource) do
                path = "#{path}/" if params[:leaf] == 'false' and path.match(/\/$/).nil?
                begin
                  name = File.basename(path)
                  result, message, is_folder = @file_support.delete_file(File.join(@file_support.root, path))
                  if result and !is_folder
                    file = @assets_model.files.find(:first, :conditions => ['name = ? and directory = ?', ::File.basename(path), ::File.dirname(path)])
                    file.destroy
                  end
                  messages << message
                rescue StandardError => ex
                  Rails.logger.error ex.message
                  Rails.logger.error ex.backtrace.join("\n")

                  ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

                  render :json => {:success => false, :error => "Error deleting #{name}"} and return
                end
              end # end current_user.with_capability
            end # end nodes_to_delete.each
            if result
              render :json => {:success => true, :message => messages.join(',')}
            else
              render :json => {:success => false, :error => messages.join(',')}
            end
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def rename_file
          path = params[:node]
          name = params[:file_name]

          result, message = @file_support.rename_file(File.join(@file_support.root, path), name)
          if result
            file = @assets_model.files.find(:first, :conditions => ['name = ? and directory = ?', ::File.basename(path), ::File.dirname(path)])
            file.name = name
            file.save
          end

          render :json => {:success => true, :message => message}
        end

        def update_security
          path = params[:path]
          secure = params[:secure]
          roles = []

          #get roles
          params.each do |k, v|
            if v == 'on'
              roles.push(k)
            end
          end

          file = @assets_model.files.where(['name = ? and directory = ?', ::File.basename(path), ::File.dirname(path)]).first

          if roles.empty?
            file.remove_capability(:download)
          else
            capability = file.add_capability(:download)
            capability.remove_all_roles
            roles.each do |r|
              role = SecurityRole.find_by_internal_identifier(r)
              role.add_capability(capability)
            end
          end

          # if we're using S3, set file permissions to private or public_read
          @file_support.set_permissions(path, (file.is_secured? ? :private : :public_read)) if ErpTechSvcs::Config.file_storage == :s3

          render :json => {:success => true, :secured => file.is_secured?, :roles => file.roles.uniq.collect { |item| item.internal_identifier }}
        end

        protected

        def set_file_support
          @file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)
        end

        def set_root_node
          @root_node = nil

          if @context == :website
            @root_node = File.join(ErpTechSvcs::Config.file_assets_location,
                                   'sites',
                                   @assets_model.iid)
          else
            @root_node = File.join(ErpTechSvcs::Config.file_assets_location,
                                   "dba_organizations",
                                   current_user.party.dba_organization.id.to_s,
                                   "shared_site_files")
          end

          @root_node
        end

        def set_asset_model
          @context = params[:context].to_sym

          if @context == :website
            website_id = params[:website_id]
            (@assets_model = website_id.blank? ? nil : Website.find(website_id))

            render :inline => {:success => false, :error => "No Website Selected"}.to_json if (@assets_model.nil? && params[:action] != "base_path")
          else
            @assets_model = CompassAeInstance.find_by_internal_identifier('base')
          end
        end

      end #FileAssetsController
    end #Desktop
  end #ErpApp
end #Knitkit
