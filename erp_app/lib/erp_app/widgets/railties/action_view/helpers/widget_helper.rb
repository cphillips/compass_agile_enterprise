module ErpApp
  module Widgets
    module Railties
      module ActionView
        module Helpers
          module WidgetHelper

            def render_widget(name, opts={})
              action = opts[:action] || :index
              params = opts[:params].nil? ? {} : opts[:params]
              render_inline = opts[:render_inline] === false ? false : true
         
              uuid = Digest::SHA1.hexdigest(Time.now.to_s + rand(10000).to_s)

              if render_inline
                #render widget
                widget_obj = "::Widgets::#{name.to_s.camelize}::Base".constantize.new(self.controller, name.to_s, action.to_s, uuid, params, nil)
                result = widget_obj.process(action.to_s)

                html = "<div id=\"#{uuid}\" class='compass_ae-widget'>"
                html << result
                html << "</div>"
                html << "<script type='text/javascript'>"
                html << "Compass.ErpApp.Widgets.LoadedWidgets.push({id:'#{uuid}',name:'#{name.to_s}',action:'#{action.to_s}',params:#{params.to_json}});"
                html << "</script>"

              else
                html = "<div id=\"#{uuid}\" class='compass_ae-widget'>Loading ...<script type=\"text/javascript\">Compass.ErpApp.Widgets.setup('#{uuid}', '#{name}', '#{action}', #{params.to_json}, true);</script></div>"
              end

              raw html
            end

            def build_widget_url(action, id=nil, params={})
              url = if id
                "/erp_app/widgets/#{@name}/#{action}/#{@uuid}/#{id}"
              else
                "/erp_app/widgets/#{@name}/#{action}/#{@uuid}"
              end

              if params
                url = "#{url}?"
                params.each do |k, v|
                  url += "#{k.to_s}=#{v.to_s}&"
                end
                url = url[0...url.length - 1]
              end

              url
            end

            def widget_result_id
              "#{@uuid}_result"
            end

            def include_widgets
              raw ErpApp::Widgets::JavascriptLoader.glob_javascript
            end

            def get_widget_action
              params[:widget_action] || 'index'
            end

            def set_widget_params(widget_params={})
              widget_params.merge!(params.symbolize_keys)
              widget_params
            end

          end #WidgetHelper
        end #Helpers
      end #ActionView
    end #Railties
  end #Widgets
end #ErpApp
