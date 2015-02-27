module Integrations::Crm::Salesforce
  extend Redis::IntegrationsRedis
  extend Redis::RedisKeys

  def self.included(base)
    base.send :extend, ClassMethods
    base.send :extend, Redis::IntegrationsRedis
    base.send :extend, Redis::RedisKeys
  end

  # should handle syncing existing contacts and companies
  # should debug messages - now puts statements
  # Differentiate b/w imported contacts, single contact and prev. existing contacts
  # existing contacts, flag is available and then sync from import class or module....
  # Should handle oauth token

  module ClassMethods

    include Integrations::OauthHelper

    APPCONFIG = (YAML::load_file File.join(Rails.root, 'config', 'oauth_config.yml'))["defaults"]["salesforce"]

    def sync_contacts_with_salesforce(options, sf_account_id)
      sObject = :Contact
      installed_application = Account.current.installed_applications.with_name("salesforce").first
      body = build_contact_body(installed_application, options, sf_account_id)
      crm_contact = Integrations::CrmContact.find_by_installed_application_id_and_local_integratable_id(
        installed_application.id,
        options["id"])
      if crm_contact.nil?
        query = "SELECT Name FROM #{sObject.to_s} WHERE Email LIKE '#{options["email"]}'"
        json_response = JSON.parse get_object(query, installed_application)[:text]
        if json_response["totalSize"] < 1
          puts "SALESFORCE_SYNC::Message Creating a new contact #{options}"
          rest_url = "services/data/v20.0/sobjects/#{sObject.to_s}/"
          params = build_post_request(body.to_json, installed_application, rest_url)
          response = JSON.parse make_request("salesforce", params, installed_application)[:text]
          push_to_crm_contact(response["id"], options["id"], installed_application.id)
          return
        elsif json_response["totalSize"] == 1
          puts "SALESFORCE_SYNC::Message Updating the contact #{options}"
          sf_id = json_response["records"][0]["attributes"]["url"].split("/").last
          body[:Id] = sf_id
          push_to_crm_contact(sf_id, options["id"], installed_application.id)
        else
          puts "SALESFORCE_SYNC::Error Found more than one contact for #{options}"
          return
        end
      else
        puts "SALESFORCE_SYNC::Message Updating the contact #{options}"
        body[:Id] = crm_contact.remote_integratable_id
      end
      set_contact_to_redis(body)
    end

    def push_existing_contacts
      
    end

    def bulk_export_contacts_to_salesforce(options)
      installed_application = Account.current.installed_applications.with_name("salesforce").first
      sf_headers = get_sf_headers(installed_application[:configs][:inputs]["contacts"], options)
      records_to_update = Array.new
      pending_records = Array.new
      pending_emails = Array.new
      contact_records = Array.new
      company_names = Array.new
      options[:fd_records].each do |value|
        account_to_sync = get_contact_row(sf_headers, value)
        # At this point AccountId is company_name, it should be set to appropriate account id from salesforce
        if account_to_sync["Email"].to_s.empty?
          next
        else
          contact_records.push(account_to_sync)
          company_names.push(account_to_sync["AccountId"])
        end
      end
      salesforce = get_bulk_api_instance(installed_application)
      company_data = sort_out_companies(salesforce, company_names.uniq, installed_application)
      contact_records.each do |account_to_sync|
        # Updating with the respective Account Id
        account_to_sync["AccountId"] = company_data[account_to_sync["AccountId"]]
        # If the account is not present and to push only limited contacts
        if installed_application.configs[:inputs]["contacts_sync_type"] == "required" && account_to_sync["AccountId"].nil?
          next
        end
        crm_contact = Integrations::CrmContact.find_by_installed_application_id_and_local_integratable_id(
          installed_application.id,
          account_to_sync["ID"])
        if crm_contact.nil?
          pending_records.push(account_to_sync)
          pending_emails.push(account_to_sync["Email"])
        else
          account_to_sync["id"] = crm_contact.remote_integratable_id
          records_to_update.push(account_to_sync.reject{|k,v| (v.nil? || k == "ID")})
        end
      end
      params = sort_out_pending_contacts(salesforce, pending_emails, pending_records, records_to_update, installed_application)
      created_result = salesforce.create("Contact", params["records_to_insert"], true)
      puts "created_result : #{created_result}"
      updated_result = salesforce.update("Contact", params["records_to_update"], true)
      puts "updated_result : #{updated_result}"
      push_new_contacts(salesforce, params["new_emails"], installed_application)
    end

    def create_company(body, installed_application, company_id, sObject)
      rest_url = "services/data/v20.0/sobjects/#{sObject.to_s}/"
      params = build_post_request(body.to_json, installed_application, rest_url)
      response = JSON.parse make_request("salesforce", params, installed_application)[:text]
      push_to_crm_company(response["id"], company_id, installed_application.id)
    end

    def sync_companies_with_salesforce(options)
      sObject = :Account
      installed_application = Account.current.installed_applications.with_name("salesforce")[0]
      body = build_company_body(installed_application, options)
      crm_company = Integrations::CrmCompany.find_by_installed_application_id_and_local_integratable_id(
        installed_application.id,
        options["id"])
      if crm_company.nil?
        query = "SELECT Name FROM #{sObject.to_s} WHERE Name LIKE '#{options["name"]}'"
        json_response = JSON.parse get_object(query, installed_application)[:text]
        if json_response["totalSize"] < 1
          puts "SALESFORCE_SYNC::Message Creating a new company #{options}"
          create_company(body, installed_application, options["id"], sObject)
          return
        elsif json_response["totalSize"] == 1
          puts "SALESFORCE_SYNC::Message Updating the company #{options}"
          sf_id = json_response["records"][0]["attributes"]["url"].split("/").last
          body[:Id] = sf_id
          push_to_crm_company(sf_id, options["id"], installed_application.id)
        else
          puts "SALESFORCE_SYNC::Error Found more than one company for #{options}"
          return
        end
      else
        puts "SALESFORCE_SYNC::Message Updating the company #{options}"
        body[:Id] = crm_company.remote_integratable_id
      end
      set_company_to_redis(body)
    end

    def bulk_export_existing_records_to_salesforce(options)
      current_companies = Account.current.companies
      current_users = Account.current.users
      installed_application = Account.current.installed_applications.with_name("salesforce")[0]
      records_to_update = Array.new
      pending_records = Array.new
      pending_names = Array.new
      current_companies.each do |company|
        account_to_sync = build_company_body(installed_application, company)
        crm_company = Integrations::CrmCompany.find_by_installed_application_id_and_local_integratable_id(
          installed_application.id,
          account_to_sync["ID"])
        if crm_company.nil? # Also check what type of sync this is. If it is 2 way, this step is not required
          pending_records.push(account_to_sync)
          pending_names.push(account_to_sync["Name"])
        else
          account_to_sync["id"] = crm_company.remote_integratable_id
          records_to_update.push(account_to_sync.reject{|k,v| (v.nil? || k == "ID")})
        end
      end
      salesforce = get_bulk_api_instance(installed_application)
      params = sort_out_pending_companies(salesforce, pending_names, pending_records, records_to_update, installed_application)
      created_result = salesforce.create("Account", params["records_to_insert"], true)
      puts "created_result : #{created_result}"
      updated_result = salesforce.update("Account", params["records_to_update"], true)
      puts "updated_result : #{updated_result}" 
      push_new_companies(salesforce, params["new_names"], installed_application)

      installed_application = Account.current.installed_applications.with_name("salesforce").first
      records_to_update = Array.new
      pending_records = Array.new
      pending_emails = Array.new
      contact_records = Array.new
      company_names = Array.new
      current_users.each do |user|
        sf_account_id = Account.current.crm_companies.find_by_local_integratable_id(user.customer_id).remote_integratable_id
        if user.email.empty? || (installed_application.configs[:inputs]["contacts_sync_type"] == "required" && sf_account_id.nil?)
          next
        else
          account_to_sync = build_contact_body(installed_application, user, sf_account_id)
          salesforce = get_bulk_api_instance(installed_application)
          crm_contact = Integrations::CrmContact.find_by_installed_application_id_and_local_integratable_id(
            installed_application.id,
            account_to_sync["ID"])
          if crm_contact.nil?
            pending_records.push(account_to_sync)
            pending_emails.push(account_to_sync["Email"])
          else
            account_to_sync["id"] = crm_contact.remote_integratable_id
            records_to_update.push(account_to_sync.reject{|k,v| (v.nil? || k == "ID")})
          end
        end
        params = sort_out_pending_contacts(salesforce, pending_emails, pending_records, records_to_update, installed_application)
        created_result = salesforce.create("Contact", params["records_to_insert"], true)
        puts "created_result : #{created_result}"
        updated_result = salesforce.update("Contact", params["records_to_update"], true)
        puts "updated_result : #{updated_result}"
        push_new_contacts(salesforce, params["new_emails"], installed_application)
      end
    end

    def bulk_export_companies_to_salesforce(options)
      installed_application = Account.current.installed_applications.with_name("salesforce")[0]
      sf_headers = get_sf_headers(installed_application[:configs][:inputs]["companies"], options)
      records_to_update = Array.new
      pending_records = Array.new
      pending_names = Array.new
      options[:fd_records].each do |value|
        account_to_sync = get_company_row(sf_headers, value)
        crm_company = Integrations::CrmCompany.find_by_installed_application_id_and_local_integratable_id(
          installed_application.id,
          account_to_sync["ID"])
        if crm_company.nil? # Also check what type of sync this is. If it is 2 way, this step is not required
          pending_records.push(account_to_sync)
          pending_names.push(account_to_sync["Name"])
        else
          account_to_sync["id"] = crm_company.remote_integratable_id
          records_to_update.push(account_to_sync.reject{|k,v| (v.nil? || k == "ID")})
        end
      end
      salesforce = get_bulk_api_instance(installed_application)
      params = sort_out_pending_companies(salesforce, pending_names, pending_records, records_to_update, installed_application)
      created_result = salesforce.create("Account", params["records_to_insert"], true)
      puts "created_result : #{created_result}"
      updated_result = salesforce.update("Account", params["records_to_update"], true)
      puts "updated_result : #{updated_result}" 
      push_new_companies(salesforce, params["new_names"], installed_application)
    end

    def set_contact_to_redis(body)
      sf_account = Integrations::SalesforceAccount.find_by_account_id(Account.current.id)
      # To avoid if the sync is disabled at some later point of time
      unless sf_account.nil?
        redis_key = "CRM_CONTACT_SYNC:#{Account.current.id}:#{sf_account.last_sync_time}"
        redis_value = get_integ_redis_key(redis_key)
        if redis_value.nil? || redis_value.empty?
          set_integ_redis_key(redis_key, key_options.inspect)
          sf_account.update_attributes({:push_record_to_salesforce => true})
          redis_value = eval(get_integ_redis_key(redis_key))
        else
          redis_value = eval(redis_value)
        end
        redis_value[:records] << body
        set_integ_redis_key(redis_key, redis_value.inspect)
      end
    end

    def set_company_to_redis(body)
      sf_account = Integrations::SalesforceAccount.find_by_account_id(Account.current.id)
      # To avoid if the sync is disabled at some later point of time
      unless sf_account.nil?
        redis_key = "CRM_COMPANY_SYNC:#{Account.current.id}:#{sf_account.last_sync_time}"
        redis_value = get_integ_redis_key(redis_key)
        if redis_value.nil? || redis_value.empty?
          set_integ_redis_key(redis_key, key_options.inspect)
          sf_account.update_attributes({:push_record_to_salesforce => true})
          redis_value = eval(get_integ_redis_key(redis_key))
        else
          redis_value = eval(redis_value)
        end
        redis_value[:records] << body
        set_integ_redis_key(redis_key, redis_value.inspect)
      end
    end

    

    

    def sort_out_companies(salesforce, company_names, installed_application)
      avai_names = Hash.new
      company_names.each do |comp|
        crm_company = Account.current.crm_companies.with_name(comp).first
        avai_names[comp] = crm_company.remote_integratable_id
      end
      new_names = company_names - avai_names.keys
      unless new_names.empty?
        query_result = query_companies(salesforce, new_names)
        query_result["batches"][0]["response"].each do |r|
          avai_names[r["Name"][0]] = r["Id"][0]
        end
        # If only contacts for avail companies to be updated, then this process is not necessary
        unless installed_application.configs[:inputs]["contacts_sync_type"] == "required"
          new_names = company_names - avai_names.keys
          records_to_insert = Array.new
          new_names.each do |company_name|
            records_to_insert.push({"Name" => company_name})
          end
          unless new_names.empty?
            created_result = salesforce.create("Account", records_to_insert, true)
            puts "created_result : #{created_result}"
            query_result = push_new_companies(salesforce, new_names, installed_application)
            query_result["batches"][0]["response"].each do |r|
              avai_names[r["Name"][0]] = r["Id"][0]
            end
          end
        end
      end
      avai_names
    end

    def sort_out_pending_companies(salesforce, company_names, company_records, records_to_update, installed_application)
      records_to_insert = Array.new
      query_result = query_companies(salesforce, company_names)
      avai_names = Hash.new
      query_result["batches"][0]["response"].each do |r|
        avai_names[r["Name"][0]] = r["Id"][0]
      end
      new_names = company_names - avai_names.keys
      company_records.each do |account_to_sync|
        if avai_names.keys.include?(account_to_sync["Name"])
          push_to_crm_company(avai_names[account_to_sync["Name"]], account_to_sync["ID"], installed_application.id)
          account_to_sync = account_to_sync.reject{|k,v| (v.nil? || k == "ID")}
          account_to_sync["Id"] = avai_names[account_to_sync["Name"]]
          records_to_update.push(account_to_sync)
        else
          records_to_insert.push(account_to_sync.reject{|k,v| (v.nil? || k == "ID")})
        end
      end
      params = {
        "records_to_insert" => records_to_insert,
        "records_to_update" => records_to_update,
        "new_names" => new_names
      }
    end

    def push_new_contacts(salesforce, new_emails, installed_application)
      query_result = query_contacts(salesforce, new_emails)
      query_result["batches"][0]["response"].each do |re|
        user = User.find_by_email(re["Email"][0])
        push_to_crm_contact(re["Id"][0], user.id, installed_application.id)
      end
    end

    def push_new_companies(salesforce, new_names, installed_application)
      query_result = query_companies(salesforce, new_names)
      query_result["batches"][0]["response"].each do |re|
        company = Company.find_by_name(re["Name"][0])
        push_to_crm_company(re["Id"][0], company.id, installed_application.id)
      end
      query_result
    end

    def query_companies(salesforce, company_names)
      salesforce.query("Account",
        "select id, name from Account where name in (#{"'" + company_names.join("','") + "'"})")
    end

    def query_contacts(salesforce, contact_emails)
      res = salesforce.query("Contact",
        "select id, name, email from Contact where email in (#{"'" + contact_emails.join("','") + "'"})")
    end

    def sort_out_pending_contacts(salesforce, contact_emails, contact_records, records_to_update, installed_application)
      records_to_insert = Array.new
      query_result = query_contacts(salesforce, contact_emails)
      avai_emails = Hash.new
      query_result["batches"][0]["response"].each do |r|
        avai_emails[r["Email"][0]] = r["Id"][0]
      end
      new_emails = contact_emails - avai_emails.keys
      contact_records.each do |account_to_sync|
        if avai_emails.keys.include?(account_to_sync["Email"])
          push_to_crm_contact(avai_emails[account_to_sync["Email"]], account_to_sync["ID"], installed_application.id)
          account_to_sync = account_to_sync.reject{|k,v| (v.nil? || k == "ID")}
          account_to_sync["Id"] = avai_emails[account_to_sync["Email"]]
          records_to_update.push(account_to_sync)
        else
          records_to_insert.push(account_to_sync.reject{|k,v| (v.nil? || k == "ID")})
        end
      end
      params = {
        "records_to_insert" => records_to_insert,
        "records_to_update" => records_to_update,
        "new_emails" => new_emails
      }
    end

    def push_to_crm_contact(sf_response_id, user_id, installed_application_id)
      crm_contact = Integrations::CrmContact.new
      crm_contact[:installed_application_id] = installed_application_id
      crm_contact[:remote_integratable_id] = sf_response_id
      crm_contact[:local_integratable_id] = user_id
      crm_contact[:account_id] = Account.current.id
      crm_contact.save!
    end

    def push_to_crm_company(sf_response_id, company_id, installed_application_id)
      crm_company = Integrations::CrmCompany.new
      crm_company[:installed_application_id] = installed_application_id
      crm_company[:remote_integratable_id] = sf_response_id
      crm_company[:local_integratable_id] = company_id
      crm_company[:account_id] = Account.current.id
      crm_company.save!
    end

    def key_options
      {
        :account_id => Account.current.id,
        :provider => "salesforce",
        :records => []
      }
    end

    def get_sf_headers(fields_map, options)
      hash = Hash.new
      fields_map.each do |val|
        hash[val[:fd_field]] = val[:sf_field]
      end
      sf_headers = Hash.new
      options[:params]["customers"]["fields"].each do |key, value|
        sf_headers[hash[key]] = value
      end
      sf_headers.reject{|k,v| k.nil?}
    end

    def get_bulk_api_instance(installed_application)
      client = Databasedotcom::Client.new(
        :client_id => APPCONFIG["consumer_token"],
        :client_secret => APPCONFIG["consumer_secret"])
      client.authenticate(
        :token => installed_application[:configs][:inputs]["oauth_token"], # Handle if oauth_token expired
        :instance_url => installed_application[:configs][:inputs]["instance_url"])
      salesforce = SalesforceBulkApi::Api.new(client)
    end

    def get_contact_row(sf_headers, value) # Since i have a flat structure, I don't have to consider cf_
      account_to_sync = Hash.new
      sf_headers.each do |key, val|
        if key == "Name"
          name = value[val.to_i].split(" ", 2)
          account_to_sync[:FirstName] = name[0]
          account_to_sync[:LastName] = name[1] || "."
          next
        end
        account_to_sync[key] = value[val.to_i]
      end
      # Dumping freshdesk ID
      account_to_sync["ID"] = value[-1]
      account_to_sync
    end

    def get_company_row(sf_headers, value)
      account_to_sync = Hash.new
      sf_headers.each do |key, val|
        account_to_sync[key] = value[val.to_i]
      end
      # Dumping freshdesk ID
      account_to_sync["ID"] = value[-1]
      account_to_sync
    end

    def build_contact_body(installed_application, options, sf_account_id)
      body_hash = Hash.new
      installed_application.configs[:inputs]["contacts"].each do |k| 
        if k["fd_field"].starts_with("cf_")
          body_hash[k["sf_field"]] = options["custom_field"][k["fd_field"]]
        else
          body_hash[k["sf_field"]] = options[k["fd_field"]] 
        end
      end
      name = options["name"].split(" ", 2)
      body_hash["FirstName"] = name[0]
      body_hash["LastName"] = name[1] || "."
      body_hash["AccountId"] = sf_account_id
      unless body_hash["Name"].nil?
        body_hash.delete("Name")
      end
      body_hash
    end

    def build_company_body(installed_application, options)
      body_hash = Hash.new
      installed_application.configs[:inputs]["companies"].each do |k| 
        if k["fd_field"].starts_with("cf_")
          body_hash[k["sf_field"]] = options["custom_field"][k["fd_field"]]
        else
          body_hash[k["sf_field"]] = options[k["fd_field"]] 
        end
      end
      body_hash["Name"] = options["name"]
      body_hash
    end

    def get_object(query, installed_application)
      params = application_params.merge({
        :domain => installed_application[:configs][:inputs]["instance_url"],
        :method => "get",
        :rest_url => "services/data/v20.0/query/?q=#{query}"
        })
      make_request("salesforce", params, installed_application)
    end

    def build_post_request(body, installed_application, rest_url)
      application_params.merge({
        :domain => installed_application[:configs][:inputs]["instance_url"],
        :method => "post",
        :body => body,
        :rest_url => rest_url
        })
    end

    def application_params
      {
        :ssl_enabled => "false",
        :content_type => "application/json",
        :accept_type => "application/json"
      }
    end

    def make_request(app, params, installed_application)
      ua = "Mozilla" # /5.0 (Macintosh; Intel Mac OS X 10_8_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.95 Safari/537.36"
      hrp = HttpRequestProxy.new
      reqParams = {
        :user_agent => ua,
        :auth_header => "OAuth " + installed_application[:configs][:inputs]["oauth_token"]
      }
      response = hrp.fetch_using_req_params params, reqParams
      if response[:status] == 401
        ac = refresh_access_token(app)
        reqParams = {
          :user_agent => ua,
          :auth_header => "OAuth " + ac
        }
        response = hrp.fetch_using_req_params params, reqParams
      end
      response
    end
  end
end