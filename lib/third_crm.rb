class ThirdCRM
  EVENTS = {
    subscription: 'subscription',
    trial_subscription: 'trial_subscription',
    beacon_report: 'beacon_report',
    onboarding_goals: 'onboarding_goals'
  }

  FRESHMARKETER_EVENTS = {
    goal_completed: 'fdesk trial goal completed',
    fdesk_event: 'fdesk trial events'
  }.freeze
  PRODUCT_NAME = "Freshdesk"

  ADD_LEAD_WAIT_TIME = 5
  FRESHMARKETER_API_HEADERS = { 'fm-token' => ThirdCrm::FRESHMARKETER_CONFIG['access_key'], 'Content-Type' => 'application/json' }

  REQUEST_TYPES = {
    get: 'get',
    post: 'post',
    put: 'put',
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

  FRESHMARKETER_REQUEST_TYPES = ['post', 'put', 'delete'].freeze

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

  def publish_event(account, args)
    if args[:event_name].present?
      event_data = { args[:event_name] => true, 'Trial Day' => ((Time.now.to_i - account.subscription.created_at.to_i) / 86400).to_i }
    else
      event_data = { 'GoalName': args[:goal_name] }
    end
    add_event(event_data, account, args)
  end

  def update_lead_info(admin_email)
    associated_account_ids = associated_accounts(admin_email)
    remaining_account_ids = ((associated_account_ids.present? ? associated_account_ids.split(',') : []) - ["#{Account.current.id}"]).join(',')
    contact_data = { 'custom' => { 'string--Associated--Accounts': remaining_account_ids.present? ? remaining_account_ids : nil } }
    update_lead(contact_data.merge('Email' => admin_email))
  end

  private

    def associated_accounts(admin_email)
      # Fetch list of associated accounts from dynamodb for the given email id
      associated_accounts = AdminEmail::AssociatedAccounts.find admin_email
      # Creating comma separated account ids
      associated_account_id_list = nil
      if associated_accounts.present?
        associated_account_id_list = associated_accounts.map(&:id).join(',')
      end
      associated_account_id_list
    end

    def lead_info(account)
      associated_account_ids = associated_accounts(account.admin_email)
      account_info = user_info(account, associated_account_ids)
      subscription_info = subscription_info(account)
      misc = account.conversion_metric ? signup_info(account.conversion_metric) : {'default' => {}, 'custom' => {}}
      lead_details = account_info['default'].merge(misc['default'])
      lead_details["custom"] = account_info['custom'].merge(subscription_info['custom']).merge(misc['custom'])
      {"contact" => lead_details}
    end

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

    def onboarding_goals_info(account, args)
      onboarding_goals = account.account_additional_settings.additional_settings[:onboarding_goals]
      onboaring_goals_info = {}
      onboarding_goals.each do |a|
        onboaring_goals_info[TrialWidgetConstants::GOALS_AND_STEPS[a.to_sym][:custom_name]] = true
      end
      {
        custom: onboaring_goals_info,
        Email: args[:email],
        LastName: args[:name]
      }
    end

    def add_lead_to_crm(lead_record)
      # AP trigger endpoint does 2 things
      # 1. upserts contact
      # 2. onboards contact to the given trigger

      # FM doesn't provide trigger api. So, workaround is to
      # 1. upsert contact first
      make_fm_api(REQUEST_TYPES[:put], ThirdCrm::FRESHMARKETER_CONFIG['contact_url'], lead_record)
      # 2. add contact to list (set trigger to that list in the FM app).
      lead_record['lists'] = [ThirdCrm::FRESHMARKETER_CONFIG['list_id']]
      make_fm_api(REQUEST_TYPES[:put], ThirdCrm::FRESHMARKETER_CONFIG['contact_url'], lead_record)
    end

    def update_lead(lead_record)
      make_fm_api(REQUEST_TYPES[:put], ThirdCrm::FRESHMARKETER_CONFIG['contact_url'], lead_record)
    end

    def add_event(event_record, account, args)
      make_fm_api(REQUEST_TYPES[:post], ThirdCrm::FRESHMARKETER_CONFIG['events_url'] + "?email=#{account.admin_email}&event_name=#{args[:event]}", event_record)
    end

    def user_info(account, associated_account_id_list)
      account_info = {
          "default" => (LEAD_INFO["default"].inject({}) { |h, (k, v)| h[k] = account.safe_send(v); h }).merge(clearbit_info(account)),
          "custom" => LEAD_INFO["custom"].inject({}) { |h, (k, v)| h[k] = account.safe_send(v); h }.merge(
            {'string--Associated--Accounts' => associated_account_id_list })
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

    def make_fm_api(req_type, url, data = {})
      if FRESHMARKETER_REQUEST_TYPES.include?(req_type)
        begin
          if req_type.to_s == REQUEST_TYPES[:delete]
            RestClient.safe_send(
              req_type,
              url,
              FRESHMARKETER_API_HEADERS
            )
          else
            fm_payload = data.deep_dup
            lists = fm_payload.delete('lists')
            fm_payload = transform_for_fm(fm_payload['contact'] || fm_payload)
            fm_payload['lists'] = lists if lists.present?
            RestClient.safe_send(
              req_type,
              url,
              fm_payload.to_json,
              FRESHMARKETER_API_HEADERS
            )
          end
        rescue RestClient::Conflict => e
          err_msg = "Contact already present in Freshmarketer list :: FD AccountId: #{Account.current.id} err: #{e}"
          Rails.logger.error(err_msg)
          NewRelic::Agent.notice_error(e, description: err_msg)
        rescue => e
          err_response = e.response if e.instance_of?(RestClient::BadRequest)
          err_msg = "Error sending contact data to Freshmarketer :: FD AccountId: #{Account.current.id} e.message:#{e.message} e.response:#{err_response} req_type:#{req_type} url:#{url} fm_payload:#{fm_payload.to_json}"
          Rails.logger.error(err_msg)
          NewRelic::Agent.notice_error(e, description: err_msg)
        end
        Rails.logger.info("make_fm_api successful for #{url} #{req_type} account_id:#{Account.current.id}")
      end
    end

    def transform_for_fm(data)
      fm_data = { 'custom_field' => {} }
      return unless data.is_a?(Hash)

      Rails.logger.info("ap_payload:#{data.to_json}")
      transform(data.stringify_keys!, fm_data)
      transform(data['default'].stringify_keys!, fm_data) if data.key?('default')
      fm_data = transform(data['custom'].stringify_keys!, fm_data) if data.key?('custom')
      Rails.logger.info("fm_payload:#{fm_data.to_json}")
      fm_data
    end

    def transform(ap_data, fm_data)
      ap_data.each do |ap_key, val|
        if ThirdCrm::AP_VS_FM_DEFAULT_FIELDS.key?(ap_key)
          fm_data[ThirdCrm::AP_VS_FM_DEFAULT_FIELDS[ap_key]] = val.to_s
        elsif ThirdCrm::AP_VS_FM_CUSTOM_FIELDS.key?(ap_key)
          fm_data['custom_field'][ThirdCrm::AP_VS_FM_CUSTOM_FIELDS[ap_key]] = val.to_s
        end
      end
      fm_data
    end
end
