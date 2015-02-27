namespace :salesforce_sync do
  
  desc "Sync contacts and companies with salesforce"

  task :import => :environment do
    Sharding.execute_on_all_shards do
      Integrations::SalesforceImporter.sync_salesforce_contacts_and_companies
    end
  end

  task :export => :environment do
    Sharding.execute_on_all_shards do
      Integrations::SalesforceExporter.sync_salesforce_contacts_and_companies
    end
  end
end