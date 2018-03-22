module InstalledApplicationsTestHelper
  def installed_application_pattern(app, _output = {})
    {
      id: app.id,
      application_id: app.application_id,
      name: app.application.name,
      configs: validate_configs(app),
      display_name: app.application.display_name,
      display_option: Integrations::Constants::APPS_DISPLAY_MAPPING[app.application.name]
    }
  end

  def integrated_user_pattern(app, _output = {})
    {
      id: app.id,
      installed_application_id: app.installed_application_id,
      user_id: app.user_id,
      auth_info: validate_auth_hash(app.auth_info),
      remote_user_id: app.remote_user_id
    }
  end

  def validate_configs(app)
    return {} unless app.configs[:inputs].present?
    configs_hash = app.configs[:inputs]
    if app.application.name == 'dropbox'
      return configs_hash
    else
      configs_hash.symbolize_keys.except(*Integrations::Constants::EXCLUDE_FROM_APP_CONFIGS_HASH)
    end
  end

  def validate_auth_hash(auth_info)
    return {} unless auth_info.present?
    auth_info.symbolize_keys.except(*Integrations::Constants::EXCLUDE_FROM_APP_CONFIGS_HASH)
  end

  def create_application(app_name, options = {})
    application = Integrations::Application.find_by_name(app_name)
    unless application
      application = FactoryGirl.build(:application, name: app_name,
              display_name: Integrations::Constants::APPS_DISPLAY_MAPPING[app_name], 
              listing_order: Integrations::Application.count + 1,
              account_id: Account.current.id, application_type: options[:application_type])
      application.save
    end
    installed_app = Account.current.installed_applications.where(
      application_id: application.id)
    unless installed_app.present?
      configs = respond_to?("#{app_name}_config") ? 
        safe_send("#{app_name}_config") : {}
      installed_app = create_installed_applications({ 
          account_id: Account.current.id, 
          application_name: app_name, 
          configs: configs
        })
    end
    installed_app
  end

  def zohocrm_config
    { inputs: { api_key: 'cd8947e9c1cbea743ea9057450b0f5c4', 
      domain: 'https://crm.zoho.com' } }
  end

  def harvest_config
    { inputs: { title: 'Harvest', domain: 'starimpact.harvestapp.com',
      harvest_note: 'Freshdesk Ticket # {{ticket.id}}}' } }
  end

  def dropbox_config
    { inputs: { 'app_key' => '25zkc7ywmf7tnrl' } }
  end

  def create_installed_applications(options= {})
    application_id = Integrations::Application.find_by_name(options[:application_name]).id
    installed_application = FactoryGirl.build(:installed_application, :configs => options[:configs],
                        :account_id => options[:account_id],
                        :application_id => application_id)
    installed_application.save
    installed_application
  end

  def salesforce_v2_config
    salesforce_config
  end

  def salesforce_config
    { inputs:
      { "app_name" => "salesforce",
         "oauth_token" => "00D7F000004ArcA!AQsAQNoNfzSJoFP",
         "instance_url" =>"https//ap5.salesforce.com",
         "refresh_token" => "5Aep8613hy0tHCYdhysrgytKN_zwlQ.WSj",
         "contact_fields" => "Name,Id,IsDeleted,MasterRecordId,AccountId,LastName,FirstName,Salutation,OtherStreet,OtherCity",
         "lead_fields" => "Name,Id,IsDeleted,MasterRecordId,LastName,FirstName,Salutation,Title,Company,Street",
         "account_fields" => "Name,Id,IsDeleted,MasterRecordId,Type,ParentId,BillingStreet,BillingCity,BillingState,BillingPostalCode",
         "contact_labels" => "Full Name,Contact ID,Deleted,Master Record ID,Account ID,Last Name,First Name,Salutation,Other Street,Other City",
         "lead_labels" => "Full Name,Lead ID,Deleted,Master Record ID,Last Name,First Name,Salutation,Title,Company,Street",
         "account_labels" => "Account Name,Account ID,Deleted,Master Record ID,Account Type,Parent Account ID,Billing Street,Billing City,Billing State/Province,Billing Zip/Postal Code",
         "opportunity_view" =>"1",
         "opportunity_fields" => "Name,StageName,CloseDate,Id,IsDeleted,AccountId,IsPrivate,Description,Amount,Probability",
         "opportunity_labels" => "Name,Stage,Close Date,Opportunity ID,Deleted,Account ID,Private,Description,Amount,Probability (%)",
         "agent_settings" =>"1",
         "opportunity_stage_choices" => [["Prospecting", "Prospecting"],
           ["Qualification", "Qualification"],
           ["Needs Analysis", "Needs Analysis"],
           ["Value Proposition", "Value Proposition"],
           ["Id. Decision Makers", "Id. Decision Makers"],
           ["Perception Analysis", "Perception Analysis"],
           ["Proposal/Price Quote", "Proposal/Price Quote"],
           ["Negotiation/Review", "Negotiation/Review"],
           ["Closed Won", "Closed Won"],
           ["Closed Lost", "Closed Lost"]]
    }}
  end

  def create_integ_user_credentials(options = {})
    app = Integrations::Application.find_by_name(options[:app_name])
    installed_app = @account.installed_applications.find_by_application_id(app.id)
    user_credential = installed_app.user_credentials.build
    user_credential.account_id = installed_app.account_id
    user_credential.user_id = options[:user_id]
    user_credential.remote_user_id = options[:remote_user_id]
    user_credential.auth_info = options[:auth_info]
    user_credential.save!
    user_credential
  end

  def get_installed_app(name)
    Account.current.installed_applications.preload(:application).detect { 
      |installed_application| installed_application.application.name == name }
  end

  def get_request_payload(app_id, event, type, value)
    { 
      version: 'private', 
      id: app_id, 
      event: event, 
      payload: {
        type: type, 
        value: value
      }
    }
  end

  def get_response_mock(data, status)
    mock = Minitest::Mock.new
    mock.expect :body, data
    mock.expect :status, status
    mock.expect :env, {}
    mock
  end
end
