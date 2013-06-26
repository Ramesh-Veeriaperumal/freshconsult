require 'active_record'
require 'action_controller'
require 'active_support/all'
require 'rr'

Spec::Runner.configure do |config|
  config.mock_with :rr
end

# ************* Setup Sample App ***************

plugin_spec_dir = File.dirname(__FILE__)
# This points to the sample app for testing
RAILS_ROOT = plugin_spec_dir + '/../lib/app'

def load_schema_and_data
  load_schema
  seed_data
end

def load_schema
  config = YAML::load(IO.read(File.join(RAILS_ROOT, 'config/database.yml')))
  ActiveRecord::Base.logger = Logger.new(File.join(RAILS_ROOT, 'debug.log'))
  ActiveRecord::Base.establish_connection(config)
  load(RAILS_ROOT + "/schema.rb")
end

def seed_data
  @account = Account.new(:name => "Test Account")
  @account.save!
    
  @developer = [
    :create_project,
    :edit_project
  ]
    
  @project_manager = [
    :create_project,
    :edit_project,
    :destroy_project,
    :follow_project
  ]
    
  @customer = [
    :follow_project
  ]
      
  @derrick = User.new(
    :name => "derrick",
    :account_id => @account,
    :privilege_list => @developer 
  )
  @derrick.save!    
        
  @john = User.new(
    :name => "john",
    :account_id => @account,
    :privilege_list => @project_manager 
  )
  @john.save!   
    
  @project_1 = Project.new(
    :name => "Authority 1",
    :account_id => @account,
    :user_id => @john.id
  )
  @project_1.save! 
    
  @project_2 = Project.new(
    :name => "Authority 2",
    :account_id => @account,
    :user_id => @derrick.id
  )
  @project_2.save! 
end

# ******* Load freshdesk_authority ***********
require 'authority/authorization'
require RAILS_ROOT + '/config/privileges'
require 'authority/rails/controller_helpers'
require 'authority/rails/model_helpers'
require 'authority/bookkeeper'
require 'authority/constants'

# ******* Setup sample rails app ************
Dir["#{RAILS_ROOT}/controllers/*.rb"].each {|file| require file }
Dir["#{RAILS_ROOT}/models/*.rb"].each {|file| require file }

# ******** Create privileges_test.yml file for testing *******
if File.exist?("#{RAILS_ROOT}/config/privileges_test.yml")
  File.delete("#{RAILS_ROOT}/config/privileges_test.yml")
end

@keeper = Authority::Bookkeeper.new('privileges_test.yml')
@keeper.map(Authority::Authorization::PrivilegeList.privileges_by_name)


