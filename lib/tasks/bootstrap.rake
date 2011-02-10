#SAAS starts here
namespace :db do
  desc 'Load an initial set of data'
  task :bootstrap => :environment do
    puts 'Creating tables...'
    Rake::Task["db:migrate"].invoke
    
    puts 'Loading data...'
    Rake::Task["db:seed_fu"].invoke

    #We do not need savage_beast migration here, all the forums
    #related tables should have been created as part of 'db:schema:load' rake.
    #puts 'Bootstraping savage_beast...'
    #Rake::Task["savage_beast:bootstrap_db"].invoke
    
    puts 'Changing secret in environment.rb...'
    new_secret = ActiveSupport::SecureRandom.hex(64)
    config_file_name = File.join(RAILS_ROOT, 'config', 'environment.rb')
    config_file_data = File.read(config_file_name)
    File.open(config_file_name, 'w') do |file|
      file.write(config_file_data.sub('9cb7f8ec7e560956b38e35e5e3005adf68acaf1f64600950e2f7dc9e6485d6d9c65566d193204316936b924d7cc72f54cad84b10a70a0257c3fd16e732152565', new_secret))
    end
    
    puts "All done!  You can now login to the test account at the localhost domain with the login support@freshdesk.com and password test.\n\n"
  end
     
end
#SAAS ends here
