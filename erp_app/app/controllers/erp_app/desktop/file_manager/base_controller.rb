require 'fileutils'

module ErpApp
  module Desktop
    module FileManager
      class BaseController < ErpApp::Desktop::BaseController

        before_filter :set_file_support

        ROOT_NODE = 'root_node'

        def base_path
          @base_path ||= Rails.root.to_s
        end

        def update_file
          path    = params[:node]
          content = params[:content]

          @file_support.update_file(path, content)
          render :json => {:success => true}
        end

        def create_file
          path = (params[:path] == ROOT_NODE) ? base_path : params[:path]
          name = params[:name]

          @file_support.create_file(path, name, "#Empty File")

          render :json => {:success => true, :node => @file_support.find_node(File.join(path, name), {keep_full_path: true})}
        end

        def create_folder
          path = (params[:path] == ROOT_NODE) ? base_path : params[:path]
          name = params[:name]

          @file_support.create_folder(path, name)
          render :json => {:success => true, :node => @file_support.find_node(File.join(path, name))}
        end

        # This method downloads a file directly from file storage (bypassing file_assets)
        # to download thru file_assets, use erp_app/public#download
        def download_file
          path = params[:path]
          contents, message = @file_support.get_contents(path)
          send_data contents, :filename => File.basename(path), :disposition => :attachment
        end

        def save_move
          messages = []
          nodes_to_move = (params[:selected_nodes] ? JSON(params[:selected_nodes]) : [params[:node]])

          begin
            nodes_to_move.each do |node|
              path            = node
              new_parent_path = (params[:parent_node] == ROOT_NODE) ? base_path : params[:parent_node]
              new_parent_path = new_parent_path.gsub(base_path,'') # target path must be relative
              result, message = @file_support.save_move(path, new_parent_path)
              messages << message
            end
            render :json => {:success => true, :msg => messages.join(',')}
          rescue => ex
            Rails.logger.error(ex.message)
            Rails.logger.error(ex.backtrace.join("\n"))

            # email notification
            ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

            render :json => {:success => false, :error => ex.message}
          end
        end

        def rename_file
          path = params[:node]
          name = params[:file_name]

          result, message = @file_support.rename_file(path, name)

          render :json => {:success => result, :msg => message}
        end

        def delete_file
          messages = []
          nodes_to_delete = (params[:selected_nodes] ? JSON(params[:selected_nodes]) : [params[:node]])

          begin
            nodes_to_delete.each do |path|
              result, message = @file_support.delete_file(path)
              messages << message
            end
            render :json => {:success => true, :msg => messages.join(',')}
          rescue Exception => ex
            Rails.logger.error(ex.message)
            Rails.logger.error(ex.backtrace.join("\n"))

            # email notification
            ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

            render :json => {:success => false, :error => ex.message}
          end
        end

        def expand_directory
          path = (params[:node] == ROOT_NODE) ? base_path : params[:node]
          render :json => @file_support.build_tree(path)
        end

        def get_contents
          path = params[:node]

          contents, message = @file_support.get_contents(path)

          if contents.nil?
            render :text => message
          else
            render :text => contents
          end
        end

        def upload_file
          upload_path = params[:directory]
          upload_path = base_path if upload_path == ROOT_NODE

          result = upload_file_to_path(upload_path)

          render :inline => result.to_json
        end

        def replace_file
          begin
            contents, message = @file_support.get_contents(params["replace_file_data"].path)

            new_path = File.join(params["node"].split('/').reverse.drop(1).reverse.join('/'), params["replace_file_data"].original_filename)

            @file_support.replace_file(params["node"],
                                       new_path,
                                       contents)

            render :json => {:success => true, name: params["replace_file_data"].original_filename, path: new_path}
          rescue Exception => ex
            Rails.logger.error(ex.message)
            Rails.logger.error(ex.backtrace.join("\n"))

            # email notification
            ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

            render :json => {:success => false, :error => ex.message}
          end
        end

        protected

        def upload_file_to_path(upload_path, valid_file_type_regex=nil)
          result = {}

          FileUtils.mkdir_p(upload_path) unless File.directory? upload_path

          upload_path = params[:directory]
          name = params[:name]
          contents = request.raw_post

          #Rails.logger.info contents
          if !valid_file_type_regex.nil? && name !=~ valid_file_type_regex
            result[:success] = false
            result[:error]   = "Invalid file type"
          elsif File.exists? "#{upload_path}/#{name}"
            result[:success] = false
            result[:error]   = "file #{name} already exists"
          else
            @file_support.create_file(upload_path, name, contents)
            result[:success] = true
            result[:node] = @file_support.find_node(File.join(upload_path, name), {keep_full_path: true})
          end

          result
        end

        def set_file_support
          @file_support = ErpTechSvcs::FileSupport::Base.new
        end

      end
    end
  end
end
