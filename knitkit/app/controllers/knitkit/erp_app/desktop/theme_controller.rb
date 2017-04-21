module Knitkit
  module ErpApp
    module Desktop
      class ThemeController < ::ErpApp::Desktop::FileManager::BaseController
        before_filter :set_file_support
        before_filter :set_website, :only => [:index, :new, :change_status, :available_themes]
        before_filter :set_theme, :only => [:delete, :change_status, :theme_widget, :available_widgets]
        IGNORED_PARAMS = %w{action controller node_id theme_data}

        def index
          if params[:node] == ROOT_NODE
            setup_tree
          else
            theme = get_theme(params[:node])
            unless theme.nil?
              render :json => @file_support.build_tree(params[:node], :file_asset_holder => theme, :preload => true)
            else
              render :json => {:success => false, :message => 'Could not find theme'}
            end
          end
        end

        def available_themes
          render :json => {:success => true,
                           :themes => @website.themes.map { |theme| {:id => theme.id, :name => theme.name} }}
        end

        def available_widgets
          render :json => {:success => true,
                           :widgets => @theme.non_themed_widgets.map { |widget| {:id => widget, :name => widget.humanize} }}
        end

        def theme_widget
          @theme.create_layouts_for_widget(params[:widget_id])
          render :json => {:success => true}
        end

        def new
          begin
            current_user.with_capability('view', 'Theme') do
              unless params[:theme_data].blank?
                theme = Theme.import(params[:theme_data], @website)
              else
                theme = Theme.create(:website => @website, :name => params[:name], :theme_id => params[:theme_id])
                theme.version = params[:version]
                theme.author = params[:author]
                theme.homepage = params[:homepage]
                theme.summary = params[:summary]
                theme.save
                theme.create_theme_files!
              end
              render :inline => {:success => true, :node => build_tree_node(theme, @website)}.to_json
            end
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def update
          begin
            current_user.with_capability('view', 'Theme') do
              theme = Theme.find(params[:id])
              theme.name = params[:name].strip
              if theme.save
                render :json => {
                  success: true,
                  theme: {
                    name: theme.name,
                    text: "#{theme.name}[#{theme.theme_id}]"
                  }
                }
              else
                render :json => {success: false}
              end
            end
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def delete
          begin
            current_user.with_capability('view', 'Theme') do
              if @theme.destroy
                render :json => {:success => true}
              else
                render :json => {:success => false}
              end
            end
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def export
          theme = Theme.find(params[:id])
          zip_path = theme.export
          send_file(zip_path.to_s, :stream => false) rescue raise "Error sending #{zip_path} file"
        end

        def change_status
          begin
            current_user.with_capability('view', 'Theme') do
              #clear active themes
              @website.deactivate_themes! if (params[:active] == 'true')
              (params[:active] == 'true') ? @theme.activate! : @theme.deactivate!

              render :json => {:success => true}
            end
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        ##############################################################
        #
        # Overrides from ErpApp::Desktop::FileManager::BaseController
        #
        ##############################################################

        def create_file
          begin
            current_user.with_capability('view', 'Theme') do
              path = File.join(@file_support.root, params[:path])
              name = params[:name]

              theme = get_theme(path)
              theme.add_file('#Empty File', File.join(path, name))

              render :json => {:success => true, :node => @file_support.find_node(File.join(path, name), {:file_asset_holder => theme})}
            end
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def replace_file
          begin
            contents, message = @file_support.get_contents(params["replace_file_data"].path)

            new_dir = params[:node].split('/').reverse.drop(1).reverse.join('/')
            new_name = params["replace_file_data"].original_filename

            new_path = File.join(new_dir, new_name)

            theme_file = get_theme_file(params[:node])
            
            theme_file.replace!(params[:node], new_path, contents)

            render :json => {:success => true, name: params["replace_file_data"].original_filename, path: new_path, url: theme_file.data.url}
          rescue Exception => ex
            Rails.logger.error(ex.message)
            Rails.logger.error(ex.backtrace.join("\n"))

            # email notification
            ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

            render :json => {:success => false, :error => ex.message}
          end
        end

        def create_folder
          begin
            current_user.with_capability('view', 'Theme') do
              path = File.join(@file_support.root, params[:path])
              name = params[:name]

              @file_support.create_folder(path, name)
              render :json => {:success => true, :node => @file_support.find_node(File.join(path, name), {keep_full_path: false})}
            end
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def update_file
          begin
            current_user.with_capability('view', 'Theme') do
              path = File.join(@file_support.root, params[:node])
              content = params[:content]

              type = File.extname(File.basename(path)).gsub(/^\.+/, '').to_sym
              result = Knitkit::SyntaxValidator.validate_content(type, content)

              unless result
                @file_support.update_file(path, content)
                render :json => {:success => true}
              else
                render :json => {:success => false, :message => result}
              end
            end
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def save_move
          result = {}
          nodes_to_move = (params[:selected_nodes] ? JSON(params[:selected_nodes]) : [params[:node]])
          begin
            nodes_to_move.each do |node|
              current_user.with_capability('view', 'Theme') do
                path = File.join(@file_support.root, node)
                new_parent_path = File.join(@file_support.root, params[:parent_node])

                unless @file_support.exists? path
                  result = {:success => false, :msg => 'File does not exist.'}
                else
                  theme_file = get_theme_file(path)
                  theme_file.move(params[:parent_node])
                  result = {:success => true, :msg => "#{File.basename(path)} was moved to #{new_parent_path} successfully"}
                end
              end
            end
            render :json => result
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def download_file
          begin
            current_user.with_capability('view', 'Theme') do
              path = File.join(@file_support.root, params[:path])
              contents, message = @file_support.get_contents(path)

              send_data contents, :filename => File.basename(path)
            end
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def get_contents
          path = File.join(@file_support.root, params[:node])
          contents, message = @file_support.get_contents(path)

          if contents.nil?
            render :text => message
          else
            render :text => contents
          end
        end

        def upload_file
          begin
            current_user.with_capability('view', 'Theme') do
              result = {}
              upload_path = params[:directory]
              name = params[:name]
              data = request.raw_post

              theme = get_theme(upload_path)
              name = File.join(@file_support.root, upload_path, name)

              begin
                theme.add_file(data, name)
                result = {:success => true, :node => @file_support.find_node(name, {:file_asset_holder => theme})}
              rescue => ex
                logger.error ex.message
                logger.error ex.backtrace.join("\n")
                result = {:success => false, :error => "Error uploading #{name}"}
              end

              render :inline => result.to_json
            end
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def delete_file
          messages = []
          nodes_to_delete = (params[:selected_nodes] ? JSON(params[:selected_nodes]) : [params[:node]])
          begin
            result = false
            nodes_to_delete.each do |path|
              current_user.with_capability('view', 'Theme') do
                begin
                  name = File.basename(path)
                  result, message, is_folder = @file_support.delete_file(File.join(@file_support.root, path), {force: true})
                  if result && !is_folder
                    theme_file = get_theme_file(path)
                    theme_file.destroy
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
          begin
            current_user.with_capability('view', 'Theme') do
              result = {:success => true, :data => {:success => true}}
              path = params[:node]
              name = params[:file_name]

              result, message = @file_support.rename_file(File.join(@file_support.root, path), name)
              if result
                theme_file = get_theme_file(path)
                theme_file.name = name
                theme_file.save
              end

              render :json => {:success => true, :message => message}
            end
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def get_ckeditor_selectable_themes
          themes = []
          Theme.where('active = ?', 1).all.each do |theme|
            theme_hash = {:name => theme.name, :theme_id => theme.theme_id, :stylesheets => []}
            theme.stylesheets.each do |stylesheet|
              theme_hash[:stylesheets] << {:name => stylesheet.name, :url => stylesheet.data.url}
            end
            themes << theme_hash
          end

          render :json => {:success => true, :themes => themes}
        end

        protected

        def get_theme(path)
          sites_index = path.index('sites')
          sites_path = path[sites_index..path.length]
          site_name = sites_path.split('/')[1]
          site = Website.find_by_internal_identifier(site_name)

          themes_index = path.index('themes')
          path = path[themes_index..path.length]
          theme_name = path.split('/')[1]
          @theme = site.themes.find_by_theme_id(theme_name)

          @theme
        end

        def get_theme_file(path)
          theme = get_theme(path)
          file_dir = ::File.dirname(path).gsub(Regexp.new(Rails.root.to_s), '')
          theme.files.where('name = ? and directory = ?', ::File.basename(path), file_dir).first
        end

        def build_tree_node(theme, website)

          theme_hash = {
            :name => theme.name,
            :text => "#{theme.name}[#{theme.theme_id}]",
            :handleContextMenu => true,
            :siteId => website.id,
            :isActive => (theme.active == 1), :iconCls => 'icon-content',
            :isTheme => true,
            :id => theme.id,
            :children => []
          }
          if theme.active == 1
            theme_hash[:iconCls] = 'icon-add'
          else
            theme_hash[:iconCls] = 'icon-delete'
          end

          ['stylesheets', 'javascripts', 'images', 'templates', 'widgets', 'fonts'].each do |resource_folder|
            theme_hash[:children] << {
              :themeId => theme.id,
              :siteId => website.id,
              :text => resource_folder.capitalize,
              :iconCls => 'icon-content',
              :handleContextMenu => (resource_folder == 'widgets'),
              :id => "#{theme.url}/#{resource_folder}"
            }
          end
          theme_hash
        end

        def setup_tree
          tree = []

          if @website
            #handle themes
            @website.themes.each do |theme|
              theme_hash = build_tree_node(theme, @website)
              tree << theme_hash
            end
          end

          render :json => tree
        end

        def set_theme
          @theme = Theme.find(params[:theme_id])
        end

        def set_file_support
          @file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)
        end

        def set_website
          if params[:website_id]
            @website = Website.find(params[:website_id])
          end
        end

      end #ThemeController
    end #Desktop
  end #ErpApp
end #Knitkit
