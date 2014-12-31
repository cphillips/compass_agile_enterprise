class MobileApplicationGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('../templates', __FILE__)
  argument :description, :type => :string 
  argument :icon, :type => :string 

  def generate_mobile_application
    # Controller
    template "controllers/controller_template.erb", "app/controllers/erp_app/mobile/#{file_name}/base_controller.rb"

    # make javascript
    template "assets/app.js.erb", "app/assets/javascripts/erp_app/mobile/applications/#{file_name}/app.js"
    
    # make css folder
    empty_directory "app/assets/stylesheets/erp_app/mobile/applications/#{file_name}"

    # make images folder
    empty_directory "app/assets/images/erp_app/mobile/applications/#{file_name}"
    
    # add route
    route "match '/erp_app/mobile/#{file_name}(/:action)' => \"erp_app/mobile/#{file_name}/base\""
    
    # migration
    template "migrate/migration_template.erb", "db/data_migrations/#{RussellEdge::DataMigrator.next_migration_number(1)}_create_#{file_name}_mobile_application.rb"
  end
end
