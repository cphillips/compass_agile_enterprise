![Logo][engines/erp_app/public/images/art/compass-logo-1.png]

===Welcome to Compass Agile Enterprise===

Compass Agile Enterprise is a set of Rails Engines that incrementally add the functionality of an ERP and CMS to a Rails application.

It is meant to stay completely out of the directories that a Rails application developer would use, so your app and public directories and clean for you to use.

=================

Compass.rake README

TASK DESCRIPTIONS
=================

compass:install:core - installs the core compass plugins

compass:install:default - installs the core compass plugin and the default (eCommerce) plugins

compass:bootstrap:data -This rake task orchestrates the several additional tasks in the following sequence

compass:bootstrap:copy_ignored_data_migrations - copies the data migrations from the 'default plugins'
                                                  data_migrations/ignore dir up to the data_migrations dir
 
 db:migrate_data- executes the data migrations moved by the previous task
 
 compass:bootstrap:delete_data_migrations - deletes the recently moved data migrations
 
 
 
 COMPASS_INSTALLATION
 ====================
 
 Compass installation follows the following simple four step process:
 
 (Step 1) Create a new Rails application using the compass installer template
     
     rails [myappname] -m ./compass_install.rb
          -OR-
     rails [myappname] -m http://[host]:[port]/[path_to_installer_file]/compass_install.rb