class Integrations::SalesforceImporter

  APPCONFIG = (YAML::load_file File.join(Rails.root, 'config', 'oauth_config.yml'))["defaults"]["salesforce"]

  def self.sync_salesforce_contacts_and_companies

    puts "sync_salesforce_contacts_and_companies is called via rake"

    salesforce_accounts = Integrations::SalesforceAccount.records_to_pull(DateTime.now.utc - (1/24.0))

    salesforce_accounts.each do |salesforce_account|
      current_account = Account.find(salesforce_account.id)
      installed_application = current_account.installed_applications.with_name("salesforce")[0]

      sf_company_field_list = ['Id','Name']
      company_fields_hash = {}
      installed_application[:configs][:inputs]["companies"].each do |c_f|
        sf_company_field_list << c_f["sf_field"]
        company_fields_hash[c_f["sf_field"].downcase] = c_f["fd_field"]
      end
      company_result = get_companies(installed_application, salesforce_account, sf_company_field_list)
      push_companies_to_db(company_result, company_fields_hash, installed_application)

      # Test contacts

      sf_contact_field_list = ['Id','Email','AccountId']
      contact_fields_hash = {}
      installed_application[:configs][:inputs]["contacts"].each do |c_f|
        sf_contact_field_list << c_f["sf_field"]
        contact_fields_hash[c_f["sf_field"].downcase] = c_f["fd_field"]
      end
      contact_result = get_contacts(installed_application, salesforce_account)
      push_contacts_to_db(contact_result, contact_fields_hash, installed_application)
    end
  end

  def self.get_companies(installed_application, salesforce_account, sf_company_field_list)
    options = set_options(salesforce_account, installed_application)
    bulk_api = authenticate(installed_application)
    company_query = "SELECT #{sf_company_field_list.uniq*','} FROM Account"
    company_result = bulk_api.query("Account", company_query, options)
  end

  def self.get_contacts(installed_application, salesforce_account, sf_contact_field_list)
    options = set_options(salesforce_account, installed_application)
    bulk_api = authenticate(installed_application)
    contact_query = "SELECT #{sf_contact_field_list.uniq*','} FROM Contact"
    contact_result = bulk_api.query("Contact", contact_query, options)
  end

  def self.set_options(salesforce_account, installed_application)
    options = {}
    if !salesforce_account.pushed_existing_records && installed_application[:configs][:inputs]["sync_existing_data"]
      options[:created_from] = "1989-01-01T00:00:00.000Z"
    else
      options[:created_from] = salesforce_account.last_sync_time
    end
    options[:date_field] = "LastModifiedDate"
    options
  end

  def self.authenticate(installed_application)
    restforce = Restforce.new(
      :refresh_token => installed_application[:configs][:inputs]["refresh_token"],
      :client_id => APPCONFIG["consumer_token"],
      :client_secret => APPCONFIG["consumer_secret"])
    SalesforceBulkQuery::Api.new(restforce, :logger => Logger.new(STDOUT))
  end

  def self.push_contacts_to_db(contact_result, contact_fields_hash, installed_application)
    company_result[:filenames].each do |fn|
      if File.exist?(fn)
        records = SmarterCSV.process(fn, {:key_mapping => contact_fields_hash.symbolize_keys})
        records.each do |rec|
          # Also check here if email id should be present and is present
          contact_mapped = Integrations::CrmContact.find_by_installed_application_id_and_remote_integratable_id(
            installed_application.id,
            rec[:id]
            )
          if contact_mapped.nil?
            user = User.find_by_email(rec[:email])
          else
            user = User.find(contact_mapped.local_integratable_id)
          end
          if user.nil?
            user = User.new
          end
          user = set_contact_object(rec, user, installed_application)
          user.signup!
          if contact_mapped.nil?
            push_to_crm_contact(installed_application, user, rec)
          end
        end
      end
    end
  end

  def self.push_companies_to_db(company_result, company_fields_hash, installed_application)
    company_result[:filenames].each do |fn|
      if File.exist?(fn)
        records = SmarterCSV.process(fn, {:key_mapping => company_fields_hash.symbolize_keys})
        records.each do |rec|
          company_mapped = Integrations::CrmCompany.find_by_installed_application_id_and_remote_integratable_id(
            installed_application.id,
            rec[:id]
            )
          if company_mapped.nil?
            company = Company.find_by_name(rec[:name])
          else
            company = Company.find(company_mapped.local_integratable_id)
          end
          if company.nil?
            company = Company.new
          end
          company = set_company_object(rec, company, installed_application)
          company.save!
          if company_mapped.nil?
            push_to_crm_company(installed_application, company, rec)
          end
        end
      end        
    end
  end

  def self.set_company_object(rec, company, installed_application)
    rec.each do |key,val|
      if key.to_s == "id"
        next
      elsif key.to_s.starts_with("cf_")
        company["custom_field"][key] = val
      else
        company[key] = val
      end
    end
    company.account_id = installed_application.account_id
    company
  end

  def self.set_contact_object(rec, user, installed_application)
    rec.each do |key,val|
      if key.to_s == "id"
        next
      elsif key.to_s.starts_with("cf_")
        user["custom_field"][key] = val
      else
        user[key] = val
      end
    end
    user.account_id = installed_application.account_id
    user
  end

  def self.push_to_crm_company(installed_application, company, rec)
    company_mapped = Integrations::CrmCompany.new
    company_mapped.installed_application_id = installed_application.id
    company_mapped.local_integratable_id = company.id
    company_mapped.remote_integratable_id = rec[:id]
    company_mapped.account_id = installed_application.account_id
    company_mapped.save!
  end

  def self.push_to_crm_contact(installed_application, user, rec)
    contact_mapped = Integrations::CrmContact.new
    contact_mapped.installed_application_id = installed_application.id
    contact_mapped.local_integratable_id = user.id
    contact_mapped.remote_integratable_id = rec[:id]
    contact_mapped.account_id = installed_application.account_id
    contact_mapped.save!
  end
end