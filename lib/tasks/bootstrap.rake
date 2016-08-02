#SAAS starts here
namespace :db do
  desc 'Load an initial set of data'
  task :bootstrap => :environment do
    unless Rails.env.production?
      puts 'Creating tables...'
      Rake::Task["db:schema:load"].invoke
  #    Rake::Task["db:migrate"].invoke
      Rake::Task["db:create_reporting_tables"].invoke unless Rails.env.production?
      
      Rake::Task["db:create_trigger"].invoke #To do.. Need to make sure the db account has super privs.
      Rake::Task["db:perform_table_partition"].invoke

      create_es_indices
      
      puts 'Loading data...'
      ENV["FIXTURE_PATH"] = "db/fixtures/global"
      Rake::Task["db:seed_fu"].invoke

      #We do not need savage_beast migration here, all the forums
      #related tables should have been created as part of 'db:schema:load' rake.
      #puts 'Bootstraping savage_beast...'
      #Rake::Task["savage_beast:bootstrap_db"].invoke

      puts "Populating the default record for global_blacklisted_ips table"
      PopulateGlobalBlacklistIpsTable.create_default_record
      
      puts 'Changing secret in environment.rb...'
      new_secret = SecureRandom.hex(64)
      config_file_name = File.join(Rails.root, 'config', 'environment.rb')
      config_file_data = File.read(config_file_name)
      File.open(config_file_name, 'w') do |file|
        file.write(config_file_data.sub('9cb7f8ec7e560956b38e35e5e3005adf68acaf1f64600950e2f7dc9e6485d6d9c65566d193204316936b924d7cc72f54cad84b10a70a0257c3fd16e732152565', new_secret))
      end
      
      puts "All done!  You can now login to the test account at the localhost domain with the login #{Helpdesk::EMAIL[:sample_email]} and password test1234.\n\n"
    end
  end

  task :test_setup => :environment do
    unless Rails.env.production?
      puts 'Creating tables...'
      Rake::Task["db:schema:load"].invoke
  #    Rake::Task["db:migrate"].invoke
      Rake::Task["db:create_reporting_tables"].invoke unless Rails.env.production?
      
      Rake::Task["db:create_trigger"].invoke #To do.. Need to make sure the db account has super privs.
      Rake::Task["db:perform_table_partition"].invoke

      puts "Populating the default record for global_blacklisted_ips table"
      PopulateGlobalBlacklistIpsTable.create_default_record
    end    
  end

  task :create_reporting_tables => :environment do
    puts 'Creating reporting tables...'
    Reports::CreateReportingMonthlyTables.create_tables
  end
  
  task :create_trigger => :environment do
    puts 'Creating database trigger for tickets display id...'
    ActiveRecord::Base.connection.execute(TriggerSql.sql_for_populating_ticket_display_id)
    puts 'Creating database trigger for ticket_statuses status id...'
    ActiveRecord::Base.connection.execute(TriggerSql.sql_for_populating_custom_status_id)
    puts 'Loading Lua Script to Redis...'
    FdRateLimiter::RedisLuaScript.load_rr_lua_to_redis
  end
  
  task :perform_table_partition => :environment do
    puts 'Adding auto increment to id columns'
    PerformTablePartition.add_auto_increment
    
    puts ' partition of tables.'
    PerformTablePartition.process
  end

end

def create_es_indices
  puts 'Creating Elasticsearch indices...'
  Search::EsIndexDefinition.create_es_index
end
#SAAS ends here
