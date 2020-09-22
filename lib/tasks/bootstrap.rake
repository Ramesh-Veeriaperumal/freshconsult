#SAAS starts here
namespace :db do
  desc 'Load an initial set of data'
  task :bootstrap => :environment do
    unless Rails.env.production?
      puts 'Creating tables...'
      Rake::Task["db:schema:load"].invoke
  #    Rake::Task["db:migrate"].invoke
      #Rake::Task["db:create_reporting_tables"].invoke unless Rails.env.production?
      
      Rake::Task["db:create_trigger"].invoke #To do.. Need to make sure the db account has super privs.
      Rake::Task["db:perform_table_partition"].invoke

      #create_es_indices
      
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

  # to remove all metadata from DB and create one user (admin) for test environment
  task bootstrap_w_clean_setup: :environment do
    unless Rails.env.production?
      db_config = YAML.safe_load(IO.read(File.join(::Rails.root, 'config/database.yml')))
      new_database = db_config['test_new']['database']

      conn_config = ActiveRecord::Base.connection_config # getting old configuration
      unless conn_config[:database].eql? new_database
        conn_config[:database] = new_database # changing database name
        ActiveRecord::Base.establish_connection conn_config # establishing new connection
      end

      Rake::Task['db:bootstrap'].invoke # run bootstrap on new database
      sh "test/clean_db.sh #{new_database}" # clean all meta-data from database for clean test environment

      # create new admin in account
      account = Account.first.make_current
      user_details = {
        name: 'Support',
        email: 'sample@freshdesk.com',
        password: 'test1234',
        password_confirmation: 'test1234'
      }
      account.users.create(user_details)
      user = User.find_by_email(user_details[:email]).make_current
      user.make_agent ({ role_ids: account.roles.first.id })
      user.active = true
      user.save
      puts "All done!  You can now login to the test account at the localhost domain with the login #{Helpdesk::EMAIL[:sample_email]} and password test1234.\n\n"
    end
  end

  task :sandbox_shard_setup =>  :environment do
    unless Rails.env.production?
      shard_name = 'sandbox_shard_1'
      Sharding.run_on_shard(shard_name) do
        puts 'Creating tables...'
        Rake::Task["db:schema:load"].invoke
        #    Rake::Task["db:migrate"].invoke
        Rake::Task["db:create_reporting_tables"].invoke unless Rails.env.production?

        Rake::Task["db:create_trigger"].invoke #To do.. Need to make sure the db account has super privs.
        Rake::Task["db:perform_table_partition"].invoke
        create_es_indices
        set_auto_increment_id(shard_name, 10000000000)
      end
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

def set_auto_increment_id(shard_name,auto_increment)
  error_tables = []

# include application tables in global_tables???? as application.account_id = 0 is a valid entry

  global_tables = ['affiliate_discount_mappings', 'affiliate_discounts', 'shard_mappings', 'domain_mappings',
                   'google_domains', 'subscription_affiliates', 'subscription_announcements', 'delayed_jobs', 'features',
                   'wf_filters', 'global_blacklisted_ips', 'accounts', 'subscription_plans', 'schema_migrations',
                   'subscription_currencies', 'itil_asset_plans', 'subscription_payments', 'mailbox_jobs', 'service_api_keys',
                   'pod_shard_conditions', 'remote_integrations_mappings']
  Sharding.run_on_shard(shard_name) do
    auto_increment_id = AutoIncrementId[shard_name].to_i
    (ActiveRecord::Base.connection.tables - global_tables).each do |table_name|
      begin
        puts "Altering auto increment id for #{table_name}"
        auto_increment_query = "ALTER TABLE #{table_name} AUTO_INCREMENT = #{auto_increment_id}"
        ActiveRecord::Base.connection.execute(auto_increment_query)
      #   unless global_tables.include?(table_name)
      #     column_names = []
      #     column_values = []

      #     ActiveRecord::Base.connection.columns(table_name).each do |column|
      #       if !column.null and column.default.nil?
      #         column_names.push(column.name)

      #         if column.name == "id"
      #           column_values.push(auto_increment)
      #         elsif column.name == "account_id"
      #           table_name == "applications" ? column_values.push(-1) : column_values.push(0)
      #         elsif (column.type.to_s == "string") or (column.type.to_s == "text")
      #           column_values.push("'Freshdesk'")
      #         elsif column.type.to_s == "integer"
      #           column_values.push(1)
      #         elsif column.type.to_s == "datetime"
      #           column_values.push("'#{Time.now.to_s(:db)}'")
      #         end
      #       end
      #     end
      #     names_stuff =  column_names.join(",")
      #     values_stuff =  column_values.join(",")
      #     ActiveRecord::Base.connection.execute("insert into #{table_name}(#{names_stuff}) values(#{values_stuff})")
      #   end
      # rescue
      #   error_tables.push(table_name)
      # end
      rescue
        error_tables.push(table_name)
      end
    end
    puts "Error Tables : #{error_tables.inspect}"
  end
end

#SAAS ends here
