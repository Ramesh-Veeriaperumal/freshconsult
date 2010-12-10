#SAAS starts here
namespace :db do
  desc 'Load an initial set of data'
  task :bootstrap => :environment do
    puts 'Creating tables...'
    Rake::Task["db:migrate"].invoke
    
    puts 'Loading data...'
    if SubscriptionPlan.count == 0
      plans = [
        { 'name' => 'Free', 'amount' => 0, 'user_limit' => 2 },
        { 'name' => 'Basic', 'amount' => 10, 'user_limit' => 5 },
        { 'name' => 'Premium', 'amount' => 30, 'user_limit' => nil }
      ].collect do |plan|
        SubscriptionPlan.create(plan)
      end
    end
    
    user = User.new(:name => 'Support', :password => 'test', :password_confirmation => 'test', 
                    :email => 'support@freshdesk.com', :role_token => 'admin')
    a = Account.create(:name => 'Test Account', :domain => 'localhost', :plan => plans.first, :user => user)
    a.update_attribute(:full_domain, 'localhost')
    
    #default slas are adding here.we need to populate all these when customers signs up
    
   
    
    
    ##SLA default population ends here..
    
    puts 'Changing secret in environment.rb...'
    new_secret = ActiveSupport::SecureRandom.hex(64)
    config_file_name = File.join(RAILS_ROOT, 'config', 'environment.rb')
    config_file_data = File.read(config_file_name)
    File.open(config_file_name, 'w') do |file|
      file.write(config_file_data.sub('9cb7f8ec7e560956b38e35e5e3005adf68acaf1f64600950e2f7dc9e6485d6d9c65566d193204316936b924d7cc72f54cad84b10a70a0257c3fd16e732152565', new_secret))
    end
    
    
    #by Shan starts
    Rake::Task["bootstrap"].invoke
    Rake::Task["savage_beast:bootstrap_db"].invoke
    #by Shan ends
    
    #by shihab to populate SLA table
    Rake::Task["db:populatesla"].invoke
    
    puts "All done!  You can now login to the test account at the localhost domain with the login support@freshdesk.com and password test.\n\n"
  end
  
   task :populatesla => :environment do
       #if Helpdesk::SlaDetails.count == 0
      
      puts "populate sla is called"
      
      slas =[
      {'name' => 'Sla for low priority', 'account_id' =>Account.first.id , 'priority' =>1, 'response_time' =>86400 , 'resolution_time' =>259200, 'escalateto' =>User.first.id },
      {'name' => 'Sla for medium priority', 'account_id' =>Account.first.id , 'priority' =>2, 'response_time' =>28800 , 'resolution_time' =>86400, 'escalateto' =>User.first.id },
      {'name' => 'Sla for high priority', 'account_id' =>Account.first.id , 'priority' =>3, 'response_time' =>14400 , 'resolution_time' =>43200, 'escalateto' =>User.first.id },
      {'name' => 'Sla for urgent priority', 'account_id' =>Account.first.id , 'priority' =>4, 'response_time' =>3600 , 'resolution_time' =>14400, 'escalateto' =>User.first.id }
      
      ].collect do |sla|
      
      Helpdesk::SlaDetail.create(sla)
      
      end
      
       #end
     end
    
  
  
end
#SAAS ends here

desc 'Load the database and change the secret'
task :bootstrap => :environment do
  puts "Creating tables and admin user..."
  Rake::Task["db:migrate"].invoke
  
  puts "Changing secret in environment.rb..."
  new_secret = Rails.version < '2.2' ? Rails::SecretKeyGenerator.new('Helpdesk').generate_secret : ActiveSupport::SecureRandom.hex(64)
  config_file_name = File.join(RAILS_ROOT, 'config', 'environment.rb')
  config_file_data = File.read(config_file_name)
  File.open(config_file_name, 'w') do |file|
    file.write(config_file_data.sub('c363a47eb3d9cae948c7bb2beb216c5770dfd309c6807e70a965940f9541eb5061b8bc6486795afe049f060a1477e6812dbc346f322189dc934e43993aba58f4', new_secret))
  end
  
  puts "All done!"
end
