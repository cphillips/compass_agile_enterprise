require 'base64'

module RailsDbAdmin
  module Extensions
    module Railties
      module ActionView
        module Helpers
          module ReportHelper

            def render_report(report_iid, options={})
              report = Report.iid(report_iid)

              options[:report] = report
              options[:height] = options[:height] || 'calc(100vh - 30px)'

              render partial: '/reports/body.html.erb', locals: options
            end

            def render_report_param(report, param)
              param = Hash.symbolize_keys(param)

              case param[:type]
              when 'text'
                content_tag :div, class: 'form-group' do
                  label_tag param[:name], param[:display_name] + ': ', class: 'report-param'
                  text_field_tag param[:name], required: param[:required], class: 'form-control'
                end
              else
                content_tag :div, class: 'form-group' do
                  buffer = label_tag param[:name], param[:display_name] + ': ', class: 'report-param'

                  buffer += content_tag('div',
                              class: 'input-group date datetimepicker',
                  id: report.internal_identifier + param[:name] + '-datepicker') do

                    html = text_field_tag param[:name],
                      nil,
                      name: param[:name],
                      'date-format' => 'MM-DD-yyyy',
                      class: 'form-control'

                    html += content_tag 'span', class: 'input-group-addon' do
                      content_tag 'span', '', class: 'glyphicon glyphicon-calendar'
                    end

                    html += %{
                      <script type="text/javascript">
                      jQuery('##{report.internal_identifier + param[:name] + '-datepicker'}').datetimepicker({format: 'MM/DD/YYYY'});
                      </script>
                    }.html_safe
                  end
                end

              end

            end

            def report_download_url(report_iid, format)
              raw "/compass_ae_reports/display/#{report_iid}.#{format}"
            end

            def report_download_link(report_iid, format, display=nil)
              display = display || "Download #{format.to_s.humanize}"
              raw "<a target='_blank' href='#{report_download_url(report_iid, format)}'>#{display}</a>"
            end

            def render_template(template, locals=nil)
              if request && request.format.symbol == :html
                locals.nil? ? (render :partial => "/#{template}") : (render :partial => "/#{template}",:locals => locals[:locals])
              elsif request && request.format.symbol == :pdf
                locals.nil? ? (render :partial => "/#{template}.html.erb") : (render :partial => "/#{template}.html.erb" , :locals => locals[:locals])
              else
                locals.nil? ? (render :partial => "/#{template}.html.erb") : (render :partial => "/#{template}.html.erb" , :locals => locals[:locals])
              end
            end

            def report_stylesheet_link_tag(report_id, *sources)
              report = Report.iid(report_id)
              return("could not find report with the id #{report_id}") unless report
              if request && request.format.symbol == :pdf
                file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)
                css = sources.collect do |source|
                  css_path = report.stylesheet_path(source)
                  css_text = "<style type='text/css'>#{file_support.get_contents(css_path).first}</style>"
                  css_text.respond_to?(:html_safe) ? css_text.html_safe : css_text
                end.join("\n")
                raw css
              else
                options = sources.extract_options!.stringify_keys
                cache = options.delete("cache")
                recursive = options.delete("recursive")
                sources = report_expand_stylesheet_sources(report, sources, recursive).collect do |source|
                  report_stylesheet_tag(report, source, options)
                end.join("\n")
                raw sources
              end
            end

            def report_javascript_include_tag(report_id, *sources)
              report = Report.iid(report_id)
              return("could not find report with the id #{report_id}") unless report
              if request && request.format.symbol == :pdf
                file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)
                js = sources.collect do |source|
                  js_path = report.javascript_path(source)
                  js_text = "<script>#{file_support.get_contents(js_path).first}</script>"
                  js_text.respond_to?(:html_safe) ? js_text.html_safe : js_text
                end.join("\n")
                raw js
              else
                options = sources.extract_options!.stringify_keys
                cache = options.delete("cache")
                recursive = options.delete("recursive")
                sources = report_expand_javascript_sources(report, sources, recursive).collect do |source|
                  report_javascript_src_tag(report, source, options)
                end.join("\n")
                raw sources
              end
            end

            def report_stylesheet_path(report, source)
              report = Report.iid(report) unless report.is_a?(Report)

              name, directory = name_and_path_from_source(source, "#{report.url}/stylesheets")

              file = report.files.where('name = ? and directory = ?', name, directory).first

              file.nil? ? '' : file.fully_qualified_url
            end

            def report_javascript_path(report, source)
              report = Report.iid(report) unless report.is_a?(Report)

              name, directory = name_and_path_from_source(source, "#{report.url}/javascripts")

              file = report.files.where('name = ? and directory = ?', name, directory).first

              file.nil? ? '' : file.fully_qualified_url
            end

            def name_and_path_from_source(source, base_directory)
              path = source.split('/')
              name = path.last

              directory = if path.length > 1
                #remove last element
                path.pop

                "#{base_directory}/#{path.join('/')}"
              else
                base_directory
              end

              return name, directory
            end

            def report_expand_stylesheet_sources(report, sources, recursive = false)
              if sources.include?(:all)
                all_stylesheet_files = collect_asset_files(report.base_dir + '/stylesheets', ('**' if recursive), '*.css').uniq
              else
                sources.flatten
              end
            end

            def report_expand_javascript_sources(report, sources, recursive = false)
              if sources.include?(:all)
                collect_asset_files(report.base_dir + '/javascripts', ('**' if recursive), '*.js').uniq
              else
                sources.flatten
              end
            end

            def report_stylesheet_tag(report, source, options)
              options = {"rel" => "stylesheet", "type" => Mime::CSS, "media" => "screen",
                         "href" => html_escape(report_stylesheet_path(report, source))}.merge(options)
              tag("link", options, false, false)
            end

            def report_javascript_src_tag(report, source, options)
              options = {"type" => Mime::JS, "src" => report_javascript_path(report, source)}.merge(options)
              content_tag("script", "", options)
            end

            def report_image_tag(report_id, source, options = {})
              report = Report.iid(report_id)
              return("could not find report with the id #{report_id}") unless report

              if request && request.format.symbol == :pdf
                img_path = report.image_path(source)

                file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)

                image_tag "data:image/png;base64,#{Base64.encode64(file_support.get_contents(img_path).first)}"
              else
                options.symbolize_keys!
                options[:src] = report_image_path(report, source)
                options[:alt] ||= File.basename(options[:src], '.*').split('.').first.to_s.capitalize

                if size = options.delete(:size)
                  options[:width], options[:height] = size.split("x") if size =~ %r{^\d+x\d+$}
                end

                if mouseover = options.delete(:mouseover)
                  options[:onmouseover] = "this.src='#{report_image_path(report, mouseover)}'"
                  options[:onmouseout] = "this.src='#{report_image_path(report, options[:src])}'"
                end

                tag("img", options)
              end
            end

            def report_image_path(report, source)
              report = Report.iid(report) unless report.is_a?(Report)

              name, directory = name_and_path_from_source(source, "#{report.url}/images")

              file = report.files.where('name = ? and directory = ?', name, directory).first

              file.nil? ? '' : file.fully_qualified_url
            end

            def bootstrap_load
              stylesheet_link_tag "https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css"
            end

            def jquery_load
              javascript_include_tag "https://code.jquery.com/jquery-1.10.0.min.js"
            end

          end #ReportHelper
        end #Helpers
      end #ActionView
    end #Railties
  end #Extensions
end #RailsDbAdmin
