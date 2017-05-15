module RailsDbAdmin
  module ErpApp
    module Desktop
      class ReportsController < QueriesController

        before_filter :set_file_support

        def index
          if params[:node] == 'root_node'
            setup_tree
          else
            node = File.join(@file_support.root, params[:node])
            report = get_report(params[:node])
            unless report.nil?
              render :json => @file_support.build_tree(node, :file_asset_holder => report, :preload => true)
            else
              render :json => {:success => false, :message => 'Could not find report'}
            end
          end
        end

        def create
          begin
            ActiveRecord::Base.transaction do
              if params[:report_data].present?
                Report.import(params[:report_data])
                render :inline => {:success => true}.to_json
              else
                name = params[:name]
                internal_identifier = params[:internal_identifier]
                report = Report.new(:name => name, :internal_identifier => internal_identifier)

                report.save!

                render :json => {:success => true}
              end

            end
          rescue ActiveRecord::RecordInvalid => invalid
            Rails.logger.error invalid.record.errors.full_messages

            render json: {success: false, message: invalid.record.errors.full_messages.join('</br>')}

          rescue StandardError => ex
            Rails.logger.error ex.message
            Rails.logger.error ex.backtrace.join("\n")

            ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

            render json: {success: false, message: 'Error creating report'}

          end
        end

        def query
          render :json => {success: true, query: Report.find(params[:id]).query}
        end

        def update
          begin
            ActiveRecord::Base.transaction do
              report = Report.find(params[:id])

              report.meta_data['print_page_size'] = params[:print_page_size].strip if params[:print_page_size]
              report.meta_data['print_margin_top'] = params[:print_margin_top].strip if params[:print_margin_top]
              report.meta_data['print_margin_right'] = params[:print_margin_right].strip if params[:print_margin_right]
              report.meta_data['print_margin_bottom'] = params[:print_margin_bottom].strip if params[:print_margin_bottom]
              report.meta_data['print_margin_left'] = params[:print_margin_left].strip if params[:print_margin_left]
              report.meta_data['print_orientation'] = params[:print_orientation].strip if params[:print_orientation]
              report.meta_data['auto_execute'] = params[:auto_execute] == 'on'
              report.meta_data['can_download_csv'] = params[:can_download_csv] == 'on'
              report.meta_data['can_email'] = params[:can_email] == 'on'
              report.meta_data['can_print'] = params[:can_print] == 'on'

              unless params[:report_name].blank?
                report.name = params[:report_name].squish
              end

              unless params[:report_iid].blank?
                report.internal_identifier = params[:report_iid].squish
              end

              if params.key?(:report_params)
                report.meta_data['params'] = params[:report_params].nil? ? [] : params[:report_params]
              end

              report_roles = params[:report_roles]
              if report_roles
                available_role_types = report.role_types.pluck(:internal_identifier)
                # delete all roles associated with the report
                report.entity_party_roles.destroy_all

                # assign report roles
                report_roles.split(',').each do |role_type|
                  report.add_party_with_role(
                    current_user.party.dba_organization,
                    RoleType.iid(role_type)
                  ) unless available_role_types.include?(role_type.to_sym)
                end
              end

              render json: {success: report.save!}

            end
          rescue ActiveRecord::RecordInvalid => invalid
            Rails.logger.error invalid.record.errors.full_messages

            render json: {success: false, message: invalid.record.errors.full_messages.join('</br>')}

          rescue StandardError => ex
            Rails.logger.error ex.message
            Rails.logger.error ex.backtrace.join("\n")

            ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

            render json: {success: false, message: 'Could not save report'}

          end
        end

        def save
          id = params[:id]
          query = params[:query]
          template = params[:template]

          report = Report.find(id)

          report.query = query
          report.template = template

          if report.save
            render :json => {:success => true}
          else
            render :json => {:success => false}
          end
        end

        def save_query
          id = params[:id]
          query = params[:query]

          report = Report.find(id)

          report.query = query

          if report.save
            render :json => {:success => true}
          else
            render :json => {:success => false}
          end
        end

        def delete
          report = Report.find(params[:id])
          if report.destroy
            render :json => {:success => true}
          else
            render :json => {:success => false}
          end
        end

        def export_all
          tmp_dir = Report.make_tmp_dir
          (tmp_dir + "reports.zip").tap do |file_name|
            file_name.unlink if file_name.exist?
            Zip::ZipFile.open(file_name.to_s, Zip::ZipFile::CREATE) do |zip|
              Report.all.each.each do |report|
                zip.add("#{report.name}[#{report.internal_identifier}].zip", report.export.to_s)
              end
            end
          end

          send_file((tmp_dir + "reports.zip"), :stream => false) rescue raise "Error sending #{zip_path} file"
        end

        def export
          report = Report.find(params[:id])
          zip_path = report.export
          send_file(zip_path.to_s, :stream => false) rescue raise "Error sending #{zip_path} file"
        end

        def create_file
          begin
            path = File.join(@file_support.root, params[:path])
            name = params[:name]

            report = get_report(path)
            report.add_file('#Empty File', File.join(path, name))

            render :json => {:success => true, :node => @file_support.find_node(File.join(path, name), {:file_asset_holder => report})}
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def create_folder
          begin
            path = File.join(@file_support.root, params[:path])
            name = params[:name]
            @file_support.create_folder(path, name)
            render :json => {:success => true, :node => @file_support.find_node(File.join(path, name), {keep_full_path: false})}
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def update_file
          begin
            path = File.join(@file_support.root, params[:node])
            content = params[:content]
            @file_support.update_file(path, content)
            nodes = params[:node].split('/')
            if nodes.last == 'base.html.erb'
              report = Report.iid(nodes[nodes.index("compass_ae_reports") + 1])
              report.template = content
              report.save
            end
            render :json => {:success => true}
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def save_move
          result = {}
          nodes_to_move = (params[:selected_nodes] ? JSON(params[:selected_nodes]) : [params[:node]])
          begin
            nodes_to_move.each do |node|
              path = File.join(@file_support.root, node)
              new_parent_path = File.join(@file_support.root, params[:parent_node])

              unless @file_support.exists? path
                result = {:success => false, :msg => 'File does not exist.'}
              else
                report_file = get_report_file(path)
                report_file.move(params[:parent_node])
                result = {:success => true, :msg => "#{File.basename(path)} was moved to #{new_parent_path} successfully"}
              end
            end
            render :json => result
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

        def download_file
          begin
            path = File.join(@file_support.root, params[:path])
            contents, message = @file_support.get_contents(path)

            send_data contents, :filename => File.basename(path)
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def upload_file
          begin
            result = {}
            upload_path = params[:directory]
            name = params[:name]
            data = request.raw_post

            report = get_report(upload_path)
            name = File.join(@file_support.root, upload_path, name)

            begin
              report.add_file(data, name)
              result = {:success => true, :node => @file_support.find_node(name, {:file_asset_holder => report})}
            rescue => ex
              logger.error ex.message
              logger.error ex.backtrace.join("\n")
              result = {:success => false, :error => "Error uploading #{name}"}
            end

            render :inline => result.to_json
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
              begin
                name = File.basename(path)
                result, message, is_folder = @file_support.delete_file(File.join(@file_support.root, path), {force: true})
                if result && !is_folder
                  report_file = get_report_file(path)
                  report_file.destroy
                end
                messages << message
              rescue StandardError => ex
                Rails.logger.error ex.message
                Rails.logger.error ex.backtrace.join("\n")

                ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

                render :json => {:success => false, :error => "Error deleting #{name}"} and return
              end
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
            result = {:success => true, :data => {:success => true}}
            path = params[:node]
            name = params[:file_name]

            result, message = @file_support.rename_file(File.join(@file_support.root, path), name)
            if result
              report_file = get_report_file(path)
              report_file.name = name
              report_file.save
            end

            render :json => {:success => true, :message => message}
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def open_query
          query_name = params[:query_name]
          query = @query_support.get_query(query_name)

          render :json => {:success => true, :query => query}
        end

        def setup_tree
          tree = []
          Report.all.collect do |report|
            report_data = build_report_data(report)

            ['stylesheets', 'images', 'templates', 'javascripts', 'query'].each do |resource_folder|
              report_data[:children] << {
                :reportId => report.id,
                :reportName => report.name,
                :reportIid => report.internal_identifier,
                :text => resource_folder.titleize,
                :iconCls => case resource_folder
                when 'query'
                  'icon-query'
                else
                  'icon-content'
                end,
                :id => "#{report.url}/#{resource_folder}",
                :leaf => (resource_folder == 'query'),
                :handleContextMenu => (resource_folder == 'query') || (resource_folder == 'preview_report')
              }
            end

            tree << report_data
          end

          render :json => tree
        end

        def get_report(path)
          reports_index = path.index('reports')
          path = path[reports_index..path.length]
          report_name = path.split('/')[1]
          @report = Report.iid(report_name)

          @report
        end

        def get_report_file(path)
          report = get_report(path)
          file_dir = ::File.dirname(path).gsub(Regexp.new(Rails.root.to_s), '')
          report.files.where('name = ? and directory = ?', ::File.basename(path), file_dir).first
        end

        def set_file_support
          @file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)
        end

        private

        def build_report_data(report)
          meta_data = report.meta_data || {}
          meta_data.merge!({
                             params: report.meta_data['params'] || [],
                             roles: report.role_types.pluck(:internal_identifier).join(','),
          })

          {
            text: report.name,
            reportName: report.name,
            reportId: report.id,
            internalIdentifier: report.internal_identifier,
            iconCls: 'icon-content',
            isReport: true,
            handleContextMenu: true,
            children: [],
            reportMetaData: meta_data
          }
        end

      end # ReportsController
    end # Desktop
  end # ErpApp
end # RailsDbAdmin
