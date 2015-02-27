include Redis::IntegrationsRedis
include Redis::RedisKeys
include Integrations::Crm::Salesforce

class Integrations::SalesforceExporter

  APPCONFIG = (YAML::load_file File.join(Rails.root, 'config', 'oauth_config.yml'))["defaults"]["salesforce"]

  def self.sync_salesforce_contacts_and_companies
    puts "sync_salesforce_contacts_and_companies is called via rake"
    # Should set the last sync time as greater than or equal to - Find the mechanism
    salesforce_accounts = Integrations::SalesforceAccount.records_to_push(DateTime.now.utc - (1/24.0))

    salesforce_accounts.each do |salesforce_account|
      last_sync_time = salesforce_account.last_sync_time
      salesforce_account.update_attributes({:last_sync_time => DateTime.now, :push_record_to_salesforce => false})

      current_account = Account.find(salesforce_account.account_id)
      installed_application = current_account.installed_applications.with_name("salesforce").first

      # Need to refresh oauth token, if it has expired... find the mechanism
      client = Databasedotcom::Client.new(
        :client_id => APPCONFIG["consumer_token"],
        :client_secret => APPCONFIG["consumer_secret"])

      auth = client.authenticate(
        :token => installed_application[:configs][:inputs]["oauth_token"],
        :instance_url => installed_application[:configs][:inputs]["instance_url"])

      salesforce = SalesforceBulkApi::Api.new(client)

      account_redis_value = get_integ_redis_key("CRM_COMPANY_SYNC:#{current_account.id}:#{last_sync_time}")
      contact_redis_value = get_integ_redis_key("CRM_CONTACT_SYNC:#{current_account.id}:#{last_sync_time}")

      unless account_redis_value.nil?
        account_redis_value = eval(account_redis_value)
        account_update_result = salesforce.update("Account", account_redis_value[:records])
      end

      puts "account_update_result #{account_update_result.inspect}"

      unless contact_redis_value.nil?
        contact_redis_value = eval(contact_redis_value)
        contact_update_result = salesforce.update("Contact", contact_redis_value[:records])
      end

      puts "contact_update_result #{contact_update_result.inspect}"
    end

  end
end