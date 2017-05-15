require 'fileutils'
require 'yaml'

#redefine copy engine migrations rake task
Rake::Task["railties:install:migrations"].clear

namespace :railties do
  namespace :install do
    # desc "Copies missing migrations from Railties (e.g. plugins, engines). You can specify Railties to use with FROM=railtie1,railtie2"
    task :migrations => :'db:load_config' do
      to_load = ENV['FROM'].blank? ? :all : ENV['FROM'].split(",").map { |n| n.strip }
      #added to allow developer to perserve timestamps
      preserve_timestamp = ENV['PRESERVE_TIMESTAMPS'].blank? ? false : (ENV['PRESERVE_TIMESTAMPS'].to_s.downcase == "true")
      #refresh will replace migrations from engines
      refresh = ENV['REFRESH'].blank? ? false : (ENV['REFRESH'].to_s.downcase == "true")
      railties = ActiveSupport::OrderedHash.new
      Rails.application.railties.all do |railtie|
        next unless to_load == :all || to_load.include?(railtie.railtie_name)

        if railtie.respond_to?(:paths) && (path = railtie.paths['db/migrate'].first)
          railties[railtie.railtie_name] = path
        end
      end

      on_skip = Proc.new do |name, migration|
        puts "NOTE: Migration #{migration.basename} from #{name} has been skipped. Migration with the same name already exists."
      end

      on_copy = Proc.new do |name, migration, old_path|
        puts "Copied migration #{migration.basename} from #{name}"
      end

      ActiveRecord::Migration.copy(ActiveRecord::Migrator.migrations_paths.first, railties,
                                   :on_skip => on_skip, :on_copy => on_copy, :preserve_timestamp => preserve_timestamp, :refresh => refresh)
    end
  end
end

namespace :db do
  namespace :migrate do

    desc "list pending migrations"
    task :list_pending => :environment do
      pending_migrations = ActiveRecord::Migrator.new('up', 'db/migrate/').pending_migrations.collect { |item| File.basename(item.filename) }
      puts "================Pending Migrations=========="
      puts pending_migrations
      puts "============================================"
    end

  end #migrate
end #db

namespace :compass_ae do
  namespace :install do
    desc "Install all CompassAE schema migrations"
    task :migrations => :environment do
      compass_ae_railties = Rails.application.config.erp_base_erp_svcs.compass_ae_engines.collect { |e| "#{e.name.split("::").first.underscore}" }.join(',')
      task = "railties:install:migrations"
      ENV['FROM'] = compass_ae_railties
      Rake::Task[task].invoke
    end #migrations

    desc "Install all CompassAE data migrations"
    task :data_migrations => :environment do
      compass_ae_railties = Rails.application.config.erp_base_erp_svcs.compass_ae_engines.collect { |e| "#{e.name.split("::").first.underscore}" }.join(',')
      task = "railties:install:data_migrations"
      ENV['FROM'] = compass_ae_railties
      Rake::Task[task].invoke
    end #data_migrations

    desc "Install all CompassAE all migrations"
    task :all_migrations => :environment do
      compass_ae_railties = Rails.application.config.erp_base_erp_svcs.compass_ae_engines.collect { |e| "#{e.name.split("::").first.underscore}" }.join(',')
      ENV['FROM'] = compass_ae_railties

      task = "railties:install:migrations"
      Rake::Task[task].invoke

      task = "railties:install:data_migrations"
      Rake::Task[task].invoke
    end #migrations
  end #install

  desc "Upgrade you installation of Compass AE"
  namespace :upgrade do

    task :v1 => :environment do
      puts "Upgrading CompassAE"

      # loop through engines looking for upgrade tasks to run
      Rails.application.config.erp_base_erp_svcs.compass_ae_engines.collect { |e| "#{e.name.split("::").first.underscore}" }.each do |engine|

        if Rake::Task.task_defined?("#{engine}:upgrade:v1")
          puts "Upgrading #{engine}"

          Rake.application["#{engine}:upgrade:v1"].reenable
          Rake.application["#{engine}:upgrade:v1"].invoke
        end
      end

    end

    task :v2 => :environment do
      puts "Upgrading CompassAE"

      # loop through engines looking for upgrade tasks to run
      Rails.application.config.erp_base_erp_svcs.compass_ae_engines.collect { |e| "#{e.name.split("::").first.underscore}" }.each do |engine|

        if Rake::Task.task_defined?("#{engine}:upgrade:v2")
          puts "Upgrading #{engine}"

          Rake.application["#{engine}:upgrade:v2"].reenable
          Rake.application["#{engine}:upgrade:v2"].invoke
        end
      end

      puts "update categories to use is_tenantable"
      Category.all.each do |category|
        tenant = EntityPartyRole.where(entity_record_id: category.id, entity_record_type: 'Category', role_type_id: RoleType.iid('dba_org').id).first.try(:party)

        if tenant
          category.set_tenant!(tenant)
        end
      end

      puts "setting CompassAE instance owner"
      compass_ae_org = Organization.where(description: 'CompassAE').first
      if compass_ae_org
        CompassAeInstance.first.add_party_with_role(compass_ae_org.party, 'compass_ae_instance_owner')
      end

    end

    task :v3 => :environment do
      puts "Upgrading CompassAE"

      # loop through engines looking for upgrade tasks to run
      Rails.application.config.erp_base_erp_svcs.compass_ae_engines.collect { |e| "#{e.name.split("::").first.underscore}" }.each do |engine|

        if Rake::Task.task_defined?("#{engine}:upgrade:v3")
          puts "Upgrading #{engine}"

          Rake.application["#{engine}:upgrade:v3"].reenable
          Rake.application["#{engine}:upgrade:v3"].invoke
        end
      end

    end

  end # upgrade
end # compass_ae
