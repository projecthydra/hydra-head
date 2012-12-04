# -*- encoding : utf-8 -*-
require 'rails/generators'
require 'rails/generators/migration'     

module Hydra
class HeadGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  
  source_root File.expand_path('../templates', __FILE__)
  
  argument     :model_name, :type => :string , :default => "user"
  
    desc """
  This generator makes the following changes to your application:
    1. Creates a database migration for superusers if they do not exist in /db/migrate
    2. Adds additional mime types to you application in the file '/config/initializers/mime_types.rb'   
    3. Creates config/initializers/hydra_config.rb 
    4. Creates config/fedora.yml and config/solr.yml which you may need to modify to tell the hydra head where to find fedora & solr
    5. Creates a number of role_map config files that are used in the placeholder user roles implementation 
  Enjoy building your Hydra Head!
         """
  
  #
  # Config Files & Initializers
  #
         
  # Copy all files in templates/config directory to host config
  def create_configuration_files
    #CatalogController
    copy_file "catalog_controller.rb", "app/controllers/catalog_controller.rb"

    # Initializers
    file_path = "config/initializers/hydra_config.rb"
    copy_file "config/initializers/hydra_config.rb", file_path
    insert_into_file file_path, :after => '# specify the user model' do      
        "\n    config[:user_model] = '#{model_name.classify}'" 
    end
    

    copy_file "config/initializers/action_dispatch_http_upload_monkey_patch.rb", "config/initializers/action_dispatch_http_upload_monkey_patch.rb"

    # Role Mappings
    copy_file "config/role_map_cucumber.yml", "config/role_map_cucumber.yml"
    copy_file "config/role_map_development.yml", "config/role_map_development.yml"
    copy_file "config/role_map_production.yml", "config/role_map_production.yml"
    copy_file "config/role_map_test.yml", "config/role_map_test.yml"
   
    # Solr Mappings
    copy_file "config/solr_mappings.yml", "config/solr_mappings.yml"

    # Fedora & Solr YAML files
    begin
      invoke('active_fedora:config')
    rescue NoMethodError
      # Looks like we are falling back on the old way of doing this
      copy_file "config/fedora.yml", "config/fedora.yml"
      copy_file "config/solr.yml", "config/solr.yml"
      # Fedora & Solr Config files
      directory "fedora_conf"
      directory "solr_conf"
    end
  end
  
  # Register mimetypes required by hydra-head
  def add_mime_types
    puts "Updating Mime Types"
    insert_into_file "config/initializers/mime_types.rb", :before => 'Mime::Type.register_alias "text/plain", :refworks_marc_txt' do <<EOF
# Mime Types Added By Hydra Head:

# Mime::Type.register "text/html", :html
# Mime::Type.register "application/pdf", :pdf
# Mime::Type.register "image/jpeg2000", :jp2
Mime::Type.register_alias "text/html", :textile
Mime::Type.register_alias "text/html", :inline

EOF
    end
  end
  
  #
  # Migrations
  #
  
  # Implement the required interface for Rails::Generators::Migration.
  # taken from http://github.com/rails/rails/blob/master/activerecord/lib/generators/active_record.rb
  def self.next_migration_number(dirname)
    unless @prev_migration_nr
      @prev_migration_nr = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
    else
      @prev_migration_nr += 1
    end
    @prev_migration_nr.to_s
  end

  # Add Hydra behaviors to the user model
  def inject_hydra_user_behavior
    file_path = "app/models/#{model_name.underscore}.rb"
    if File.exists?(file_path) 
      inject_into_class file_path, model_name.classify do 
        "# Connects this user object to Hydra behaviors. " +
        "\n include Hydra::User\n"        
      end
    else
      puts "     \e[31mFailure\e[0m  Hydra requires a user object in order to apply access controls. This generators assumes that the model is defined in the file #{file_path}, which does not exist.  If you used a different name, please re-run the generator and provide that name as an argument. Such as \b  rails -g hydra:head client" 
    end    
  end
  
  # Add Hydra behaviors and Filters to CatalogController
  def inject_hydra_catalog_behavior
    puts "Adding Hydra behaviors to CatalogController"
    controller_name = "catalog_controller"
    file_path = "app/controllers/#{controller_name.underscore}.rb"
    if File.exists?(file_path) 
      insert_into_file file_path, :after => 'include Blacklight::Catalog' do      
        "\n  # Extend Blacklight::Catalog with Hydra behaviors (primarily editing)." +
        "\n  include Hydra::Controller::ControllerBehavior\n"  +
        "\n  # These before_filters apply the hydra access controls" +
        "\n  before_filter :enforce_show_permissions, :only=>:show" +
        "\n  # This applies appropriate access controls to all solr queries" +  
        "\n  CatalogController.solr_search_params_logic << :add_access_controls_to_solr_params" +  
        "\n  # This filters out objects that you want to exclude from search results, like FileAssets" +  
        "\n  CatalogController.solr_search_params_logic << :exclude_unwanted_models" 

      end
    else
      puts "     \e[31mFailure\e[0m  Could not find #{model_name.underscore}.rb.  To add Hydra behaviors to your Blacklight::Catalog Controllers, you must include the Hydra::Controller::ControllerBehavior module in the Controller class definition.  See the Hydra::Controller::ControllerBehavior section in the Hydra API Docs for more info." 
    end    
  end
  
  # Inject call to HydraHead.add_routes in config/routes.rb
  def inject_hydra_routes
    insert_into_file "config/routes.rb", :after => 'Blacklight.add_routes(self)' do
      "\n  # Add Hydra routes.  For options, see API docs for HydraHead.routes"
      "\n  HydraHead.add_routes(self)"
    end
  end
  
  # Add Hydra to the application controller
  def inject_hydra_controller_behavior    
    puts "Adding Hydra behaviors to ApplicationController"
    controller_name = "ApplicationController"
    file_path = "app/controllers/#{controller_name.underscore}.rb"
    if File.exists?(file_path) 
      insert_into_file file_path, :after => 'include Blacklight::Controller' do 
        "  \n# Adds Hydra behaviors into the application controller \n" +        
        "  include Hydra::Controller::ControllerBehavior\n"
      end
    else
      puts "     \e[31mFailure\e[0m  Could not find #{model_name.underscore}.rb.  To add Hydra behaviors to your Blacklight::Catalog Controllers, you must include the Hydra::Controller::ControllerBehavior module in the Controller class definition.  See the Hydra::Controller::ControllerBehavior section in the Hydra API Docs for more info." 
    end
  end
  
  

  
end # HeadGenerator
end # Hydra
