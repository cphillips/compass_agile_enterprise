require 'wisper'
require 'awesome_nested_set'
require "erp_base_erp_svcs/version"
require "erp_base_erp_svcs/extensions"
require "erp_base_erp_svcs/ar_fixtures"
require "erp_base_erp_svcs/config"
require "erp_base_erp_svcs/non_escape_json_string"
require "erp_base_erp_svcs/time_zone_helper"

module ErpBaseErpSvcs
  class << self
    @@root_engine_loaded = false
      
    def installed_engines
      ErpBaseErpSvcs::Config.compass_ae_engines
    end

    def installed_engine_names
      ErpBaseErpSvcs::Config.compass_ae_engines.collect do |engine|
        engine.parent_name.underscore
      end
    end

    # engine_name should be module/class name (i.e. ErpSearch)
    def engine_loaded?(engine_name)
      installed_engines.map { |compass_ae_engine| compass_ae_engine.railtie_name.camelize }.include?(engine_name)
    end

    def setup_compass_ae_callback(config, engine, &block)
      config.before_initialize do
        callback = (Rails.application.config.cache_classes ? 'after_initialize' : 'to_prepare') 
        config.send(callback) do
          block.call(engine)
        end
      end
    end

    def mount_compass_ae_engines(routes)
      installed_engines.each do |engine|
        routes.mount engine => "/#{engine.name.split("::").first.underscore}"
      end
    end

    def register_as_compass_ae_engine(config, engine)
      setup_compass_ae_callback(config, engine) do |engine|
        ErpBaseErpSvcs.load_compass_ae_engine(engine)        
      end
    end

    def load_compass_ae_engine(engine)
      installed_engines << engine unless installed_engines.include?(engine)
      load_compass_ae_extensions(engine)
    end

    #forces rails to reload model extensions and framework extensions
    def load_compass_ae_extensions(engine)
      load_compass_ae_model_extensions(engine)
      load_compass_ae_framework_extensions(engine)
    end

    def load_compass_ae_model_extensions(engine)
      root_models_path = "#{Rails.root}/app/models/"
      engine_path = engine.root.to_s
      engine_models_path = "#{engine_path}/app/models/"
      engine_extensions_path = "#{engine_models_path}extensions/"

      begin
        #get all files from this engines app/model directory
        model_extension_files = Dir.entries(engine_extensions_path).map{|directory| directory}
        #remove any .svn or .data files
        model_extension_files.delete_if{|name| name =~ /^\./}

        #Must use eval to run each extension so rails picks up the extension
        model_extension_files.each do |filename|
          #check if table exists
          content = File.open(engine_extensions_path + filename) { |f| f.read }
          class_name = filename[0..-4]
          #if tables.include?(class_name.tableize)
          eval(IO.read(engine_extensions_path + filename), binding, engine_extensions_path + filename)
          #end
        end
      end if File.directory? engine_extensions_path

      begin
        #get all files from this engines app/model directory
        model_files = Dir.entries(engine_models_path).map{|directory| directory}
        #remove any .svn or .data files
        model_files.delete_if{|name| name =~ /^\./}
        #exclude the extension directory
        model_files.delete_if{|name| name == "extensions"}

        model_files.each do |filename|

          class_name = filename[0..-4]
          klass = class_name.camelize

          #if there is a model in {rails_root}/app/models, it's not going to load our engine models.
          #load the engine model here and change it to a class_eval
          if File.exists?(root_models_path + filename)
            content = File.open(engine_models_path + filename) { |f| f.read }
            #make sure this class extends ActiveRecord::Base
            #we only want to do this for ActiveRecord models
            if content.include? '< ActiveRecord::Base'
              #if tables.include?(class_name.tableize)
              content.gsub!("class #{klass} < ActiveRecord::Base", "#{klass}.class_eval do")
              eval(content, binding)
              #end
            end
          end
        end
      end if File.directory? engine_models_path
      
    end

    def load_compass_ae_framework_extensions(engine)
      if File.directory? File.join(engine.root,"lib",engine.railtie_name,"extensions/compass_ae")
        Dir.glob(File.join(engine.root,"lib",engine.railtie_name,"extensions/compass_ae/**/*.rb")).each do |file|
          load file
        end
      end
    end

    def load_root_compass_ae_framework_extensions
      Dir.glob(File.join(Rails.root,"lib/extensions/compass_ae/**/*.rb")).sort.each do |file|
        load file
      end
    end
    
  end
end

#load the engine after this module is defined
require "erp_base_erp_svcs/engine"
