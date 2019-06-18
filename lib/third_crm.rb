class ThirdCRM
  EVENTS = {
    subscription: 'subscription',
    trial_subscription: 'trial_subscription',
    beacon_report: 'beacon_report'
  }
  PRODUCT_NAME = "Freshdesk"

  ADD_LEAD_WAIT_TIME = 5
  AUTOPILOT_CREDENTIALS = {"autopilotapikey" => AUTOPILOT_TOKENS['access_key'], "Content-Type" => 'application/json'}

  REQUEST_TYPES = {
    get: 'get',
    post: 'post',
    delete: 'delete'
  }.freeze

  AUTOPILOT_STATES = {'active' => 'Customer', 'suspended' => 'Trial Expired', 'trial' => 'Trial', 'free' => 'Free'}

  LEAD_INFO = { 
      'default' => {
        'LastName' => :admin_last_name, 'FirstName' => :admin_first_name,
        'Email' => :admin_email, 'Phone' => :admin_phone
      },
      'custom' => {
        'integer--Account--ID' => :id,
        'string--Account--URL' => :full_domain,
        'boolean--Activated'   => :verified?,
      }
    }

    SIGNUP_INFO = {
      'default' => {
        'MailingCountry' => :country, 'MailingCity' => :city_name, 'MailingState' => :region_name, 
        'MailingPostalCode' => :zip_code
      },
      'custom' => {
        'string--Other--Referrer' => :other_referrer, 'string--Signup--Referrer' => :landing_url, 
        'string--Last--Referrer' => :referrer, 'string--Original--Referrer' => :first_referrer
      }
    }

    SUBSCRIPTION_INFO = {
      'custom' => {'string--Plan' => :plan_name, 'float--Monthly--Revenue' => :cmrr, 'integer--Agent--Count' => :agent_limit,
        'string--Customer--Status' => :state, 'integer--Renewal--Period' => :renewal_period}
    }

  TRIAL_SUBSCRIPTION_ACTION_TYPE_TO_UPSELL_STATUS = {
    activate: 'true',
    cancel: 'false'
  }

  def add_signup_data(account, options = {})
    @signup_id = options[:signup_id]
    @old_email = options[:old_email]
    add_lead_to_crm(lead_info(account))
  end

  def add_or_update_contact(account, args)
    contact_data = safe_send("#{args[:event]}_info", account, args)
    contact_data.merge!(Email: account.admin_email) unless contact_data[:Email]
    update_lead(contact_data)
  end

  def update_lead_info(admin_email)
    count = associated_accounts(admin_email).split(',').count
    if count > 1
      remaining_account_ids = (@associated_account_id_list.split(',') - ["#{Account.current.id}"]).join(',')
      contact_data = { 'custom' => { 'string--Associated--Accounts' => remaining_account_ids } }
      update_lead(contact_data.merge('Email' => admin_email))
    else
      delete_lead(admin_email)
    end
  end

  def associated_accounts(admin_email)
    # Fetch list of associated accounts from dynamodb for the given email id
    associated_accounts = AdminEmail::AssociatedAccounts.find admin_email

    # Creating comma separated account ids

    if associated_accounts.present?
        @associated_account_id_list = associated_accounts.map(&:id).join(',')
    end
  end

  def lead_info(account)
    associated_accounts(account.admin_email)
    account_info = user_info(account)
    subscription_info = subscription_info(account)
    misc = account.conversion_metric ? signup_info(account.conversion_metric) : {'default' => {}, 'custom' => {}}
    lead_details = account_info['default'].merge(misc['default'])
    lead_details["custom"] = account_info['custom'].merge(subscription_info['custom']).merge(misc['custom'])
    {"contact" => lead_details}
  end

  def delete_lead(admin_email)
    trigger_url = format(AUTOPILOT_TOKENS['delete_contact_url'], email_id: admin_email)
    make_api(REQUEST_TYPES[:delete], trigger_url)
  end

  private

    def beacon_report_info(_account, args)
      {
        custom: {
          'boolean--Beacon--Opt--In': true
        },
        Email: args[:email],
        LastName: args[:name]
      }
    end

    def trial_subscription_info(account, args)
      status = TRIAL_SUBSCRIPTION_ACTION_TYPE_TO_UPSELL_STATUS[args[:action_type].to_sym]
      { 
        custom: {
          'string--Upsell--Account--URL': account.full_url,
          'string--Upsell--Account--ID': account.id.to_s,
          'boolean--Upsell--Status': status,
          'string--Upsell--Plan': args[:plan],
        },
        Email: args[:email],
        LastName: args[:name]
      }
    end

    def add_lead_to_crm(lead_record)
      trigger_url = AUTOPILOT_TOKENS['contact_with_trigger_url']  % {:trigger_code => AUTOPILOT_TOKENS['trigger_code']}
      make_api(REQUEST_TYPES[:post], trigger_url, lead_record.to_json)
    end

    def update_lead(lead_record)
      make_api(REQUEST_TYPES[:post], AUTOPILOT_TOKENS["contact_url"], {"contact" => lead_record}.to_json)
    end

    def user_info(account)
      account_info = {
          "default" => (LEAD_INFO["default"].inject({}) { |h, (k, v)| h[k] = account.safe_send(v); h }).merge(clearbit_info(account)),
          "custom" => LEAD_INFO["custom"].inject({}) { |h, (k, v)| h[k] = account.safe_send(v); h }.merge(
            {'string--Associated--Accounts' => @associated_account_id_list })
      }
      if @old_email
        account_info["default"]["Email"], account_info["default"]["_NewEmail"] = @old_email, account_info["default"]["Email"]
      end
      account_info

    end

    def clearbit_info(account)
      {
          'Company' =>  account.account_configuration.company_info[:name],
          'Title' => account.account_configuration.contact_info[:job_title],
          'Twitter' => account.account_configuration.contact_info[:twitter],
          'Linkedin' => account.account_configuration.contact_info[:linkedin],
          'MailingCountry' => account.account_configuration.contact_info[:country],
          'Industry' => account.account_configuration.company_info[:industry],
          'NumberOfEmployees' => account.account_configuration.company_info.try(:[], :metrics).try(:[], :employees)
      }
    end

    def subscription_info(account, args=nil)
      subscription = account.subscription
      {
        'custom' => SUBSCRIPTION_INFO["custom"].inject({}) { |h, (k, v)| h[k] = AUTOPILOT_STATES[subscription.safe_send(v).to_s] || subscription.safe_send(v).to_s; h }.merge(
          {  'date--Signup--Date' => subscription.created_at.strftime("%Y-%m-%d"),
            'date--Renewal--Date' => subscription.next_renewal_at.strftime("%Y-%m-%d")})
      }
    end

    def signup_info(metrics)
      {
        'default' => SIGNUP_INFO["default"].inject({}) { |h, (k, v)| h[k] = metrics.safe_send(v).to_s; h },
        'custom' => SIGNUP_INFO["custom"].inject({}) { |h, (k, v)| h[k] = metrics.safe_send(v).to_s; h }.merge(
          {"string--Signup--ID" => @signup_id})
      }
    end

    def make_api(req_type, url, data={})
      if req_type.to_s == REQUEST_TYPES[:get]
        RestClient.safe_send(req_type, url, AUTOPILOT_CREDENTIALS)
      elsif req_type.to_s == REQUEST_TYPES[:post]
        RestClient.safe_send(req_type, url, data, AUTOPILOT_CREDENTIALS)
      elsif req_type.to_s == REQUEST_TYPES[:delete]
        RestClient.safe_send(req_type, url, AUTOPILOT_CREDENTIALS)
      end
    end
end
