load File.join(File.dirname(__FILE__),'../file_support.rb')

File.unlink 'public/index.html' rescue Errno::ENOENT
FileUtils.cp File.join(File.dirname(__FILE__),'../../../public','index.html'), 'public/index.html'

CompassAeStarterKit::FileSupport.patch_file 'config/initializers/session_store.rb',
"# #{app_const}.config.session_store :active_record_store",
"#{app_const}.config.session_store :active_record_store #use active_record for session storage, this is needed for knitkit",
:patch_mode => :change

CompassAeStarterKit::FileSupport.patch_file 'config/routes.rb',
"#{app_const}.routes.draw do",
"  #mount CompassAE engines
  ErpBaseErpSvcs.mount_compass_ae_engines(self)",
:patch_mode => :insert_after

CompassAeStarterKit::FileSupport.patch_file 'config/environments/production.rb',
"  config.serve_static_assets = false",
"  config.serve_static_assets = true",
:patch_mode => :change

CompassAeStarterKit::FileSupport.patch_file 'config/environments/production.rb',
"  config.assets.compile = false",
"  config.assets.compile = true",
:patch_mode => :change

CompassAeStarterKit::FileSupport.patch_file 'Gemfile',
"gem 'jquery-rails'",
"gem 'jquery-rails', '2.1.4'",
:patch_mode => :change

CompassAeStarterKit::FileSupport.append_file 'Gemfile',
"
gem 'erp_base_erp_svcs', '3.1.5'
gem 'erp_tech_svcs', '3.1.8'
gem 'compass_ae_sencha', '1.0.3'
gem 'erp_app', '3.1.16'
gem 'knitkit', '2.1.15'
gem 'rails_db_admin', '2.1.2'
gem 'compass_ae_console', '2.0.0'
"
puts <<-end

Thanks for installing Compass AE!

We've performed the following tasks:

* Replaced the index.html page from /public with our Compass AE splash screen
* patched config/initializers/session_store.rb to use ActiveRecord for your session store
* patched config/environments/production.rb and set config.serve_static_assets = true
* patched config/environments/production.rb and set config.assets.compile = true
* Added the core Compass AE gems to your Gemfile

Now we will bundle it up and run the migrations...

end
