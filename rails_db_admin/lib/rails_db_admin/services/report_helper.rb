module RailsDbAdmin
  module Services
    class ReportHelper < AbstractController::Base
      include AbstractController::Rendering
      include AbstractController::Helpers
      include AbstractController::Translation
      include AbstractController::AssetPaths

      class Cache
        cattr_accessor :report_resolvers
      end

      # Renders report for formats
      #
      # @param report_iid [String] IID of Report
      # @param format [Symbol] Format to render the report in (:pdf, :csv)
      # @param report_params [Hash] Parameters for report
      def build_report(report_iid, formats=[:pdf, :csv], report_params={})
        begin
          @formats = formats

          database_connection_class = RailsDbAdmin::ConnectionHandler.create_connection_class(Rails.env)
          @query_support = RailsDbAdmin::QuerySupport.new(database_connection_class, Rails.env)

          @report = Report.find_by_internal_identifier(report_iid)
          @report_params = report_params

          add_report_view_paths
          build_report_data

          missing_params = check_required_params

          if missing_params.count > 0
            if missing_params.count == 1
              "#{missing_params.join(', ')} is required"
            else
              "#{missing_params.join(', ')} are required"
            end

          else
            file_attachments = []

            if @data[:error]
              @data[:error]
            else
              @formats.each do |format|
                case format
                when :html
                  data = render inline: @report.template,
                    locals: build_tpl_locals

                  file_attachments.push({name: "#{@report.name}.html", data: data})

                when :pdf
                  data = render_to_string({
                                            template: 'base.html.erb',
                                            locals: build_tpl_locals
                  })

                  file_attachments << {
                    name: "#{@report.name}.pdf",
                    data: WickedPdf.new.pdf_from_string(data, build_pdf_config)
                  }

                when :csv
                  business_module = @report_params[:business_module_id].present? ? BusinessModule.where(id: @report_params[:business_module_id]).first : nil

                  csv_data = CSV.generate do |csv|

                    custom_data_columns = []
                    if @data[:columns].include?('custom_fields')

                      custom_data = JSON.parse(@data[:rows].first['custom_fields'])

                      if business_module
                        custom_data.each do |field_name, field_value|
                          custom_data_columns << business_module.organizer_view.selected_fields.where('field_name = ?', field_name).first.label
                        end
                      else
                        custom_data_columns = custom_data.keys
                      end

                      # remove the custom_fields column if it exists
                      @data[:columns].delete('custom_fields')
                    end

                    csv << @data[:columns] + custom_data_columns

                    @data[:rows].each do |row|
                      custom_values = []

                      custom_fields = row.delete('custom_fields')

                      unless custom_fields.blank?
                        custom_data = JSON.parse(custom_fields)

                        if business_module
                          custom_data.each do |field_name, field_value|
                            case business_module.organizer_view.selected_fields.where('field_name = ?', field_name).first.field_type.internal_identifier
                            when 'address'
                              if field_value.blank?
                                custom_values << ''
                              else
                                custom_values << "#{field_value['address_line_1']} #{field_value['address_line_2']} #{field_value['city']} #{field_value['state']}, #{field_value['zip']} #{field_value['country']}"
                              end
                            else
                              custom_values << field_value
                            end

                          end
                        else
                          custom_values = custom_data.values
                        end
                      end

                      csv << row.values + custom_values
                    end
                  end

                  file_attachments << {
                    name: "#{@report.name}.csv",
                    data: csv_data
                  }
                else
                  raise 'Invalid Format'
                end
              end

              file_attachments
            end

          end

        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          # email notification
          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          "Error running report"
        end
      end

      protected

      # Get the report data by running executing the sql
      #
      def build_report_data
        if @report.query

          query = RailsDbAdmin::ErbStringParser.render(
            @report.query,
            locals: @report_params
          )
          columns, values, error = @query_support.execute_sql(query)

          @data = {columns: columns, rows: values, error: error}
        else
          @data = {columns: [], rows: [], error: nil}
        end
      end

      # build configuration to render a pdf of a report
      #
      def build_pdf_config
        time_helper = ErpBaseErpSvcs::Helpers::Time::Client.new(@report_params[:client_utc_offset])
        current_time = time_helper.in_client_time(Time.now)

        {
          page_size: @report.meta_data['print_page_size'] || 'A4',
          orientation: @report.meta_data['print_orientation'] || 'Portrait',
          margin: {
            top: (@report.meta_data['print_margin_top'].blank? ? 10 : @report.meta_data['print_margin_top'].to_i),
            bottom: (@report.meta_data['print_margin_bottom'].blank? ? 10 : @report.meta_data['print_margin_bottom'].to_i),
            left: (@report.meta_data['print_margin_left'].blank? ? 10 : @report.meta_data['print_margin_left'].to_i),
            right: (@report.meta_data['print_margin_right'].blank? ? 10 : @report.meta_data['print_margin_right'].to_i),

          },
          footer: {
            right: 'Page [page] of [topage]',
            center: "#{@report.name} ran at #{current_time.strftime('%m/%d/%Y %l:%M%p')}"
          }
        }
      end

      def add_report_view_paths
        ReportHelper::Cache.report_resolvers = [] if ReportHelper::Cache.report_resolvers.nil?

        report_path = current_report_path
        resolver = case Rails.application.config.erp_tech_svcs.file_storage
        when :s3
          path = File.join(report_path[:url], "templates")
          cached_resolver = ReportHelper::Cache.report_resolvers.find { |cached_resolver| cached_resolver.to_path == path }
          if cached_resolver.nil?
            resolver = ActionView::S3Resolver.new(path)
            ReportHelper::Cache.report_resolvers << resolver
            resolver
          else
            cached_resolver
          end
        when :filesystem
          path = "#{report_path[:path]}/templates"
          cached_resolver = ReportHelper::Cache.report_resolvers.find { |cached_resolver| cached_resolver.to_path == path }
          if cached_resolver.nil?
            resolver = ActionView::CompassAeFileResolver.new(path)
            ReportHelper::Cache.report_resolvers << resolver
            resolver
          else
            cached_resolver
          end
        end

        prepend_view_path(resolver)
      end

      def current_report_path
        {:url => @report.url.to_s, :path => @report.base_dir.to_s}
      end

      def build_tpl_locals
        @report_params.merge({
                               time_helper: ErpBaseErpSvcs::Helpers::Time::Client.new(@report_params[:client_utc_offset]),
                               formats: @formats,
                               unique_name: @report,
                               title: @report.name,
                               columns: @data[:columns],
                               rows: @data[:rows]
        })
      end

      def check_required_params
        missing_params = []

        if @report.meta_data['params']
          required_params = @report.meta_data['params'].select { |item| item['required'] === true }

          required_params.each do |required_param|
            if @report_params[required_param['name'].to_sym].blank? || @report_params[required_param['name'].to_sym] == 'null'
              missing_params.push(required_param['display_name'])
            end
          end
        end

        missing_params
      end

    end # ReportHelper
  end # Services
end # RailsDbAdmin
