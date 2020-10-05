module InstalledApplicationsTestHelper
  include CentralLib::Util

  def central_publish_installed_app_pattern(installed_app)
    {
      id: installed_app.id,
      application_id: installed_app.application_id,
      account_id: installed_app.account_id,
      encrypted_configs: encrypt_for_central(installed_app.configs.to_json.to_s, 'installed_application'),
      encryption_key_name: encryption_key_name('installed_application'),
      created_at: installed_app.created_at.try(:utc).try(:iso8601), 
      updated_at: installed_app.updated_at.try(:utc).try(:iso8601)
    }
  end

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

  def delete_all_existing_applications
    Integrations::InstalledApplication.delete_all
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
      application_id: application.id).first
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

  def shopify_config
    {
      inputs: {
        'refresh_token' => '',
        'oauth_token' => '4c8650267b720f646c64bd9e8a83271d',
        'shop_name' => 'fd-integration-private.myshopify.com',
        'shop_display_name' => 'fd-integration-private',
        'webhook_verifier' => 'effeb687d7004c39569019ca8a61111d4bcb6747ec9f3cddfbfcda468c6a9521'
      }
    }
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

  def freshsales_config
    { inputs:
      {
        "contact_fields"=> "display_name,mobile_number,contact_status_id,has_authority,do_not_disturb,time_zone,address,city,state,zipcode",
        "account_fields"=> "name,parent_sales_account_id,owner_id,number_of_employees,annual_revenue,website,phone,industry_type_id,business_type_id,territory_id",
        "lead_fields" => "display_name,first_name,last_name,owner_id,lead_stage_id,lead_reason_id,job_title,department,email,work_number",
        "contact_labels" => "Full name,Mobile,Status,Has authority,Do not disturb,Time zone,Address,City,State,Zipcode",
        "account_labels"=> "Name,Parent account,Owner,Number of employees,Annual revenue,Website,Phone,Industry type,Business type,Territory",
        "lead_labels" =>"Full name,First name,Last name,Owner,Lead stage,Unqualified reason,Job title,Department,Email,Work",
        "deal_view" => "1",
        "domain" => "https://sample.freshsales.io",
        "auth_token" => "dTetw4iu9JbVBsBfxeJ6xQ",
        "deal_fields" => "name,amount,deal_stage_id,owner_id,deal_pipeline_id,deal_reason_id,sales_account_id,contacts,deal_product_id,deal_payment_status_id",
        "deal_labels" => "Name,Deal value,Deal stage,Owner,Deal pipeline,Lost reason,Account name,Related contacts,Product,Payment status",
        "agent_settings" => "0"
      }
    }
  end

  def freshworkscrm_config
    { inputs:
      {
        'contact_fields' => 'display_name,mobile_number,contact_status_id,has_authority,do_not_disturb,time_zone,address,city,state,zipcode',
        'account_fields' => 'name,parent_sales_account_id,owner_id,number_of_employees,annual_revenue,website,phone,industry_type_id,business_type_id,territory_id',
        'contact_labels' => 'Full name,Mobile,Status,Has authority,Do not disturb,Time zone,Address,City,State,Zipcode',
        'account_labels' => 'Name,Parent account,Owner,Number of employees,Annual revenue,Website,Phone,Industry type,Business type,Territory',
        'deal_view' => '1',
        'domain' => 'https://sample.freshworks.com/crm/sales',
        'auth_token' => 'dTetw4iu9JbVBsBfxeJ6xQ',
        'deal_fields' => 'name,amount,deal_stage_id,owner_id,deal_pipeline_id,deal_reason_id,sales_account_id,contacts,deal_product_id,deal_payment_status_id',
        'deal_labels' => 'Name,Deal value,Deal stage,Owner,Deal pipeline,Lost reason,Account name,Related contacts,Product,Payment status',
        'agent_settings' => '0'
      } }
  end

  def fetch_nested_emails_response_for_freshworkscrm
    "{\"forms\":[{\"id\":2000022746,\"name\":\"DefaultContactForm\",
                \"field_class\":\"Contact\",\"fields\":[{\"id\":\"3d16cb19\",
                \"name\":\"basic_information\",\"label\":\"Basicinformation\",
                \"fields\":[{\"id\":\"aae7d8ed\",\"name\":\"telephone_numbers\",
                \"label\":\"TelephoneNumbers\",\"fields\":[{\"id\":\"aeda1254\",\"name\":\"emails\",\"type\":\"email\",
                \"label\":\"Emails\",\"fields\":[],\"form_id\":2000022746,\"visible\":\"true\",
                \"field_class\":\"Contact\",\"field_options\":{\"show_in_import\":true}},
                {\"id\":\"a65154ae\",\"name\":\"work_number\",\"type\":\"phone_number\",
                \"label\":\"Work\",\"fields\":[],\"form_id\":2000022746,\"visible\":\"true\",
                \"field_class\":\"Contact\",\"field_options\":{\"show_in_import\":true}}],\"form_id\":2000022746,
                \"field_class\":\"Contact\",\"type\":\"section\"}],
                \"form_id\":2000022746,\"field_class\":\"Contact\"}]}]}"
  end

  def form_fields_result_for_freshworkscrm
    {
      'Contact' => {
        'id' => 2_000_022_765,
        'name' => 'DefaultContactForm',
        'field_class' => 'Contact',
        'fields' => [{
          'id' => 'ead353bc-031b-4012-86b1-cd055f807c99',
          'name' => 'basic_information',
          'label' => 'Basicinformation',
          'fields' => [{
            'id' => '7e0b636d',
            'name' => 'first_name',
            'label' => 'Firstname',
            'fields' => [],
            'form_id' => 2_000_022_765,
            'field_class' => 'Contact',
            'field_options' => { 'show_in_import' => true }
          }, {
            'id' => '7e0b636de',
            'name' => 'sales_accounts',
            'label' => 'Accounts',
            'fields' => [],
            'form_id' => 2_000_022_765,
            'field_class' => 'Contact',
            'field_options' => { 'show_in_import' => true, 'creatable' => false, 'remove_item_label' => 'Remove' }
          }, {
            'id' => '7e0basd636d',
            'name' => 'emails',
            'label' => 'Emails',
            'type' => 'email',
            'fields' => [],
            'form_id' => 2_000_022_765,
            'field_class' => 'Contact',
            'visible' => 'true',
            'field_options' => { 'show_in_import' => true }
          }],
          'form_id' => 2_000_022_765,
          'field_class' => 'Contact'
        }]
      }
    }
  end

  def nested_emails_form_fields_result_for_freshworkscrm
    {
      'Contact' => {
        'id' => 2_000_022_746,
        'name' => 'DefaultContactForm',
        'field_class' => 'Contact',
        'fields' => [{
          'id' => '3d16cb19',
          'name' => 'basic_information',
          'label' => 'Basicinformation',
          'fields' => [{
            'id' => 'aae7d8ed',
            'name' => 'telephone_numbers',
            'label' => 'TelephoneNumbers',
            'fields' => [{
              'id' => 'aeda1254',
              'name' => 'emails',
              'type' => 'email',
              'label' => 'Emails',
              'fields' => [],
              'form_id' => 2_000_022_746,
              'field_class' => 'Contact',
              'visible' => 'true',
              'field_options' => { 'show_in_import' => true }
            }, {
              'id' => 'a65154ae',
              'name' => 'work_number',
              'type' => 'phone_number',
              'label' => 'Work',
              'fields' => [],
              'form_id' => 2_000_022_746,
              'field_class' => 'Contact',
              'visible' => 'true',
              'field_options' => { 'show_in_import' => true }
            }],
            'form_id' => 2_000_022_746,
            'field_class' => 'Contact',
            'type' => 'section'
          }],
          'form_id' => 2_000_022_746,
          'field_class' => 'Contact'
        }]
      }
    }
  end

  def create_integ_user_credentials(options = {})
    app = Integrations::Application.find_by_name(options[:app_name])
    installed_app = @account.installed_applications.find_by_application_id(app.id)
    installed_app = create_application(options[:app_name]) if installed_app.nil?
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

  def salesforce_v2_response_pattern(response, fields_array, type)
    response_hash = Hash.new
    field_response = JSON.parse(response)
    response_hash = {"totalSize"=> field_response.length, "done" => true, "records" => []}
    field_response.each do |response|
      hash = { "attributes"=> { "type" => type}}
      fields_array.each do |field|
        hash[field] = response[field]
      end
      hash["accountId"] = response["AccountId"] if type == "Contact" && response["AccountId"]
      hash["Id"] = response["Id"]
      hash.delete("AccountName")
      response_hash["records"].push(hash)
    end
    response_hash
  end

  def form_fields_result
    {
      'Lead' => {
        'id' => 2_000_022_766,
        'name' => 'DefaultLeadForm',
        'field_class' => 'Lead',
        'fields' => [{
          'id' => '56f639ac',
          'name' => 'basic_information',
          'label' => 'Basicinformation',
          'fields' => [{
            'id' => 'eda895ec',
            'name' => 'first_name',
            'label' => 'Firstname',
            'fields' => [],
            'form_id' => 2_000_022_766,
            'field_class' => 'Lead'
          }, {
            'id' => '7e0basd636d',
            'name' => 'emails',
            'type' => 'email',
            'label' => 'Emails',
            'fields' => [],
            'form_id' => 2_000_022_765,
            'field_class' => 'Contact',
            'visible' => 'true',
            'field_options' => { 'show_in_import' => true }
          }],
          'form_id' => 2_000_022_766,
          'field_class' => 'Lead'
        }]
      },
      'Contact' => {
        'id' => 2_000_022_765,
        'name' => 'DefaultContactForm',
        'field_class' => 'Contact',
        'fields' => [{
          'id' => 'ead353bc-031b-4012-86b1-cd055f807c99',
          'name' => 'basic_information',
          'label' => 'Basicinformation',
          'fields' => [{
            'id' => '7e0b636d',
            'name' => 'first_name',
            'label' => 'Firstname',
            'fields' => [],
            'form_id' => 2_000_022_765,
            'field_class' => 'Contact',
            'field_options' => { 'show_in_import' => true }
          }, {
            'id' => '7e0basd636d',
            'name' => 'emails',
            'label' => 'Emails',
            'type' => 'email',
            'fields' => [],
            'form_id' => 2_000_022_765,
            'field_class' => 'Contact',
            'visible' => 'true',
            'field_options' => { 'show_in_import' => true }
          }],
          'form_id' => 2_000_022_765,
          'field_class' => 'Contact'
        }]
      }
    }
  end

  def nested_emails_form_fields_result
    {
      'Lead' => {
        'id' => 2_000_022_747,
        'name' => 'DefaultLeadForm',
        'field_class' => 'Lead',
        'fields' => [{
          'id' => 'b802a38d',
          'name' => 'basic_information',
          'label' => 'Basicinformation',
          'fields' => [{
            'id' => 'd3198e57',
            'name' => 'telephone_numbers',
            'label' => 'TelephoneNumbers',
            'fields' => [{
              'id' => '9f50c437',
              'name' => 'emails',
              'type' => 'email',
              'label' => 'Emails',
              'fields' => [],
              'form_id' => 2_000_022_747,
              'field_class' => 'Lead',
              'visible' => 'true',
              'field_options' => { 'show_in_import' => true }
            }, {
              'id' => '7e0basd636d',
              'name' => 'work_number',
              'type' => 'phone_number',
              'label' => 'Work',
              'fields' => [],
              'form_id' => 2_000_022_747,
              'field_class' => 'Lead',
              'visible' => 'true',
              'field_options' => { 'show_in_import' => true }
            }],
            'form_id' => 2_000_022_747,
            'field_class' => 'Lead',
            'type' => 'section'
          }],
          'form_id' => 2_000_022_747,
          'field_class' => 'Lead'
        }]
      },
      'Contact' => {
        'id' => 2_000_022_746,
        'name' => 'DefaultContactForm',
        'field_class' => 'Contact',
        'fields' => [{
          'id' => '3d16cb19',
          'name' => 'basic_information',
          'label' => 'Basicinformation',
          'fields' => [{
            'id' => 'aae7d8ed',
            'name' => 'telephone_numbers',
            'label' => 'TelephoneNumbers',
            'fields' => [{
              'id' => 'aeda1254',
              'name' => 'emails',
              'type' => 'email',
              'label' => 'Emails',
              'fields' => [],
              'form_id' => 2_000_022_746,
              'field_class' => 'Contact',
              'visible' => 'true',
              'field_options' => { 'show_in_import' => true }
            }, {
              'id' => 'a65154ae',
              'name' => 'work_number',
              'type' => 'phone_number',
              'label' => 'Work',
              'fields' => [],
              'form_id' => 2_000_022_746,
              'field_class' => 'Contact',
              'visible' => 'true',
              'field_options' => { 'show_in_import' => true }
            }],
            'form_id' => 2_000_022_746,
            'field_class' => 'Contact',
            'type' => 'section'
          }],
          'form_id' => 2_000_022_746,
          'field_class' => 'Contact'
        }]
      }
    }
  end

  def form_fields_result_with_other_group
    {
      'Lead' => {
        'id' => 2_000_022_766,
        'name' => 'DefaultLeadForm',
        'field_class' => 'Lead',
        'fields' => [{
          'id' => '56f639ac',
          'name' => 'basic_information',
          'label' => 'Basicinformation',
          'fields' => [{
            'id' => 'eda895ec',
            'name' => 'first_name',
            'label' => 'Firstname',
            'fields' => [],
            'form_id' => 2_000_022_766,
            'field_class' => 'Lead'
          }, {
            'id' => '7e0basd636d',
            'name' => 'emails',
            'type' => 'email',
            'label' => 'Emails',
            'fields' => [],
            'form_id' => 2_000_022_765,
            'field_class' => 'Lead',
            'visible' => 'true',
            'field_options' => { 'show_in_import' => true }
          }],
          'form_id' => 2_000_022_766,
          'field_class' => 'Lead'
        }, {
          'id' => '56f638ac',
          'name' => 'other_information',
          'label' => 'Otherinformation',
          'fields' => [{
            'id' => 'eda895ec',
            'name' => 'first_name',
            'label' => 'Firstname',
            'fields' => [],
            'form_id' => 2_000_022_766,
            'field_class' => 'Lead'
          }, {
            'id' => '7e0basd636d',
            'name' => 'emails',
            'type' => 'email',
            'label' => 'Emails',
            'fields' => [],
            'form_id' => 2_000_022_765,
            'field_class' => 'Lead',
            'visible' => 'true',
            'field_options' => { 'show_in_import' => true }
          }],
          'form_id' => 2_000_022_766,
          'field_class' => 'Lead'
        }]
      },
      'Contact' => {
        'id' => 2_000_022_765,
        'name' => 'DefaultContactForm',
        'field_class' => 'Contact',
        'fields' => [{
          'id' => 'ead353bc-031b-4012-86b1-cd055f807c99',
          'name' => 'basic_information',
          'label' => 'Basicinformation',
          'fields' => [{
            'id' => '7e0b636d',
            'name' => 'first_name',
            'label' => 'Firstname',
            'fields' => [],
            'form_id' => 2_000_022_765,
            'field_class' => 'Contact',
            'field_options' => { 'show_in_import' => true }
          }, {
            'id' => '7e0basd636d',
            'name' => 'emails',
            'label' => 'Emails',
            'type' => 'email',
            'fields' => [],
            'form_id' => 2_000_022_765,
            'field_class' => 'Contact',
            'visible' => 'true',
            'field_options' => { 'show_in_import' => true }
          }],
          'form_id' => 2_000_022_765,
          'field_class' => 'Contact'
        }, {
          'id' => 'ead353bc-031b-4012-86b1-cd055f807c99',
          'name' => 'other_information',
          'label' => 'Otherinformation',
          'fields' => [{
            'id' => '7e0b636d',
            'name' => 'first_name',
            'label' => 'Firstname',
            'fields' => [],
            'form_id' => 2_000_022_765,
            'field_class' => 'Contact',
            'field_options' => { 'show_in_import' => true }
          }, {
            'id' => '7e0basd636d',
            'name' => 'emails',
            'type' => 'email',
            'label' => 'Emails',
            'fields' => [],
            'form_id' => 2_000_022_765,
            'field_class' => 'Contact',
            'visible' => 'true',
            'field_options' => { 'show_in_import' => true }
          }],
          'form_id' => 2_000_022_765,
          'field_class' => 'Contact'
          }]
      }
    }
  end

  private

    def fetch_nested_emails_response
      "{\"forms\":[{\"id\":2000022747,\"name\":\"DefaultLeadForm\",
                  \"field_class\":\"Lead\",\"fields\":[{\"id\":\"b802a38d\",
                  \"name\":\"basic_information\",\"label\":\"Basicinformation\",
                  \"fields\":[{\"id\":\"d3198e57\",\"name\":\"telephone_numbers\",
                  \"label\":\"TelephoneNumbers\",\"fields\":[{\"id\":\"9f50c437\",\"name\":\"emails\",\"type\":\"email\",
                  \"label\":\"Emails\",\"fields\":[],\"form_id\":2000022747,\"visible\":\"true\",
                  \"field_class\":\"Lead\",\"field_options\":{\"show_in_import\":true}},
                  {\"id\":\"7e0basd636d\",\"name\":\"work_number\",\"type\":\"phone_number\",
                  \"label\":\"Work\",\"fields\":[],\"form_id\":2000022747,\"visible\":\"true\",
                  \"field_class\":\"Lead\",\"field_options\":{\"show_in_import\":true}}],\"form_id\":2000022747,
                  \"field_class\":\"Lead\",\"type\":\"section\"}],
                  \"form_id\":2000022747,\"field_class\":\"Lead\"}]},
                  {\"id\":2000022746,\"name\":\"DefaultContactForm\",
                  \"field_class\":\"Contact\",\"fields\":[{\"id\":\"3d16cb19\",
                  \"name\":\"basic_information\",\"label\":\"Basicinformation\",
                  \"fields\":[{\"id\":\"aae7d8ed\",\"name\":\"telephone_numbers\",
                  \"label\":\"TelephoneNumbers\",\"fields\":[{\"id\":\"aeda1254\",\"name\":\"emails\",\"type\":\"email\",
                  \"label\":\"Emails\",\"fields\":[],\"form_id\":2000022746,\"visible\":\"true\",
                  \"field_class\":\"Contact\",\"field_options\":{\"show_in_import\":true}},
                  {\"id\":\"a65154ae\",\"name\":\"work_number\",\"type\":\"phone_number\",
                  \"label\":\"Work\",\"fields\":[],\"form_id\":2000022746,\"visible\":\"true\",
                  \"field_class\":\"Contact\",\"field_options\":{\"show_in_import\":true}}],\"form_id\":2000022746,
                  \"field_class\":\"Contact\",\"type\":\"section\"}],
                  \"form_id\":2000022746,\"field_class\":\"Contact\"}]}]}"
    end

    def fetch_email_in_other_group_response
      "{\"forms\":[{\"id\":2000022766,\"name\":\"DefaultLeadForm\",
                  \"field_class\":\"Lead\",\"fields\":[{\"id\":\"56f639ac\",
                  \"name\":\"basic_information\",\"label\":\"Basicinformation\",
                  \"fields\":[{\"id\":\"eda895ec\",\"name\":\"first_name\",
                  \"label\":\"Firstname\",\"fields\":[],\"form_id\":2000022766,
                  \"field_class\":\"Lead\"},{\"id\":\"7e0basd636d\",\"name\":\"emails\",\"type\":\"email\",
                  \"label\":\"Emails\",\"fields\":[],\"form_id\":2000022765,\"visible\":\"true\",
                  \"field_class\":\"Lead\",\"field_options\":{\"show_in_import\":true}}]
                  ,\"form_id\":2000022766,\"field_class\":\"Lead\"},
                  {\"id\":\"56f638ac\",
                  \"name\":\"other_information\",\"label\":\"Otherinformation\",
                  \"fields\":[{\"id\":\"eda895ec\",\"name\":\"first_name\",
                  \"label\":\"Firstname\",\"fields\":[],\"form_id\":2000022766,
                  \"field_class\":\"Lead\"},{\"id\":\"7e0basd636d\",\"name\":\"emails\",\"type\":\"group_field\",
                  \"label\":\"Emails\",\"fields\":[],\"form_id\":2000022765,\"visible\":\"true\",
                  \"field_class\":\"Lead\",\"field_options\":{\"show_in_import\":true}}]
                  ,\"form_id\":2000022766,\"field_class\":\"Lead\"}]},

                  {\"id\":2000022765,\"name\":\"DefaultContactForm\",\"field_class\":\"Contact\",
                  \"fields\":[{\"id\":\"ead353bc-031b-4012-86b1-cd055f807c99\",\"name\":\"basic_information\",
                  \"label\":\"Basicinformation\",\"fields\":[{\"id\":\"7e0b636d\",
                  \"name\":\"first_name\",\"label\":\"Firstname\",\"fields\":[],\"form_id\":2000022765,
                  \"field_class\":\"Contact\",\"field_options\":{\"show_in_import\":true}},
                  {\"id\":\"7e0basd636d\", \"name\":\"emails\",\"type\":\"email\",\"label\":\"Emails\",\"fields\":[],
                  \"form_id\":2000022765,\"field_class\":\"Contact\",\"visible\":\"true\",
                  \"field_options\":{\"show_in_import\":true}},{\"id\":\"c94aae94-7424-498f-863c-02bb7350724e\",
                  \"name\":\"system_information\",\"label\":\"Systeminformation\",\"fields\":[{\"id\":\"7aee054f\",
                  \"name\":\"last_contacted\",\"label\":\"Lastcontactedtime\",\"fields\":[],
                  \"form_id\":2000022765,\"field_class\":\"Contact\"}],\"form_id\":2000022765,
                  \"field_class\":\"Contact\"}],\"form_id\":2000022765,\"field_class\":\"Contact\"},

                  {\"id\":\"ead353bc-031b-4012-86b1-cd055f807c99\",\"name\":\"other_information\",
                  \"label\":\"Otherinformation\",\"fields\":[{\"id\":\"7e0b636d\",
                  \"name\":\"first_name\",\"label\":\"Firstname\",\"fields\":[],\"form_id\":2000022765,
                  \"field_class\":\"Contact\",\"field_options\":{\"show_in_import\":true}},
                  {\"id\":\"7e0basd636d\", \"name\":\"emails\",\"type\":\"group_field\",\"label\":\"Emails\",\"fields\":[],
                  \"form_id\":2000022765,\"field_class\":\"Contact\",\"visible\":\"true\",
                  \"field_options\":{\"show_in_import\":true}}],\"form_id\":2000022765,\"field_class\":\"Contact\"}]}]}"
    end
end
