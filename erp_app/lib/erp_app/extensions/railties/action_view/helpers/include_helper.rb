module ErpApp
  module Extensions
    module Railties
      module ActionView
        module Helpers
          module IncludeHelper

            def include_highslide(options = {})
              raw case options[:version].to_s.downcase
                    when 'full'
                      static_javascript_include_tag("highslide/highslide/highslide-full.js")
                    when 'gallery'
                      static_javascript_include_tag("highslide/highslide/highslide-with-gallery.js")
                    when 'html'
                      static_javascript_include_tag("highslide/highslide/highslide-with-html.js")
                    else
                      static_javascript_include_tag("highslide/highslide/highslide.js")
                  end
            end

            def setup_js_authentication(user=current_user)
              # only setup user if a current_user is logged in
              if current_user
                current_user = {
                    username: user.username,
                    profileImageUrl: user.profile_image.try(:fully_qualified_url),
                    lastloginAt: user.last_login_at,
                    lastActivityAt: user.last_activity_at,
                    failedLoginCount: user.failed_logins_count,
                    email: user.email,
                    roles: user.all_roles.collect { |role| role.internal_identifier },
                    roleTypes: user.party.role_types.collect { |role| role.internal_identifier },
                    capabilities: user.class_capabilities_to_hash,
                    id: user.id,
                    partyId: user.party.id,
                    dbaOrganizationId: user.party.dba_organization.id,
                    description: user.party.to_s
                }
                js_string = javascript_include_tag('erp_app/authentication/compass_user.js')
                js_string << (raw "<script type='text/javascript'>var currentUser = new ErpApp.CompassAccessNegotiator.CompassUser(#{current_user.to_json});</script>")
                js_string
              end
            end

            def include_code_mirror_library(theme='vibrant-ink')
              buffer = javascript_include_tag("codemirror_compassae")
              buffer << stylesheet_link_tag("codemirror_compassae")

              buffer
            end

            def include_compass_ae_instance
              compass_ae_instance = CompassAeInstance.find_by_internal_identifier('base')
              json_hash = {
                  :version => compass_ae_instance.version,
                  :installedAt => compass_ae_instance.created_at.strftime("%B %d, %Y at %I:%M%p"),
                  :lastUpdateAt => compass_ae_instance.updated_at.strftime("%B %d, %Y at %I:%M%p"),
                  :installedEngines => compass_ae_instance.installed_engines,
                  :guid => compass_ae_instance.guid
              }
              raw "<script type=\"text/javascript\">compassAeInstance = #{json_hash.to_json};</script>"
            end

            def set_session_timeout(warn_milli_seconds=((ErpApp::Config.session_warn_after*60)*1000),
                                    redirect_milli_seconds=((ErpApp::Config.session_redirect_after*60)*1000),
                                    redirect_to='/session/sign_out')
              raw "<script type='text/javascript'>Compass.ErpApp.Utility.SessionTimeout.setupSessionTimeout(#{warn_milli_seconds}, #{redirect_milli_seconds}, '#{redirect_to}') </script>" if current_user
            end

            def set_authenticity_token
              raw "<script type='text/javascript'>Compass.ErpApp.Utility.createNamespace('Compass.ErpApp'); Compass.ErpApp.AuthentictyToken = '#{form_authenticity_token}';</script>" if current_user
            end

            # need to remove camel case not rubyish, will be deprecated at some point
            alias_method :setSessionTimeout, :set_session_timeout

            def load_shared_application_resources(resource_type)
              raw case resource_type.to_sym
                    when :javascripts
                      sources = ErpApp::Config.shared_js_assets.collect { |path| javascript_include_tag(path) }.join(' ')

                      # add the root apps shared assets if they exist
                      if File.exists? File.join(Rails.root, 'app/assets/javascripts/erp_app/shared/app.js')
                        sources += javascript_include_tag('erp_app/shared/app.js')
                      end

                      sources

                    when :stylesheets
                      ErpApp::Config.shared_css_assets.collect { |path| stylesheet_link_tag(path) }.join(' ')
                  end
            end

          end #IncludeHelper
        end #Helpers
      end #ActionView
    end #Railties
  end #Extensions
end #ErpApp
