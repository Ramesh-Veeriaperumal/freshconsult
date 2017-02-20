class ThirdCRM
  PRODUCT_NAME = "Freshdesk"

  AUTOPILOT_CREDENTIALS = {"autopilotapikey" => AUTOPILOT_TOKENS['access_key'], "Content-Type" => 'application/json'}

  REQUEST_TYPES = {
    :get => "get",
    :post => "post"
  }

  AUTOPILOT_STATES = {'active' => 'Customer', 'suspended' => 'Trial Expired', 'trial' => 'Trial', 'free' => 'Free'}

  LEAD_INFO = { 
      'default' => {
        'LastName' => :admin_first_name, 'FirstName' => :admin_last_name,
        'Email' => :admin_email, 'Phone' => :admin_phone, 'Company' => :name
      },
      'custom' => {
        'integer--Freshdesk--Account--ID' => :id, 
        'string--Freshdesk--Domain--Name' => :full_domain 
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
        'string--Customer--Status' => :state, 'string--Contact--Status' => :state, 'integer--Renewal--Period' => :renewal_period}
    }

  def add_signup_data(account, options = {})
    @signup_id = options[:signup_id]
    add_lead_to_crm(lead_info(account))    
  end

  def update_subscription_data(account)
    contact_data = subscription_info(account.subscription)
    update_lead(contact_data.merge({"Email" => account.admin_email}))
  end

  def mark_as_deleted_customer
    contact_data = {"custom"=>{"string--Customer--Status"=>"Deleted"}}
    update_lead(contact_data.merge({"Email" => Account.current.admin_email}))
  end

  def lead_info(account)

    # Fetch list of associated accounts from dynamodb for the given email id
    associated_accounts = AdminEmail::AssociatedAccounts.find account.admin_email

    # Creating comma separated account ids

    if associated_accounts.present?
        @associated_account_id_list = associated_accounts.map(&:id).join(', ')
    end

    account_info = user_info(account)
    subscription_info = subscription_info(account.subscription)
    misc = account.conversion_metric ? signup_info(account.conversion_metric) : {'default' => {}, 'custom' => {}}
    lead_details = account_info['default'].merge(misc['default'])
    lead_details["custom"] = account_info['custom'].merge(subscription_info['custom']).merge(misc['custom'])
    {"contact" => lead_details}
  end


  private

    def add_lead_to_crm(lead_record)
      trigger_url = AUTOPILOT_TOKENS['contact_with_trigger_url']  % {:trigger_code => AUTOPILOT_TOKENS['trigger_code']}
      make_api(REQUEST_TYPES[:post], trigger_url, lead_record.to_json)
    end

    def update_lead(lead_record)
      make_api(REQUEST_TYPES[:post], AUTOPILOT_TOKENS["contact_url"], {"contact" => lead_record}.to_json)
    end

    def user_info(account)
      {
        "default" => LEAD_INFO["default"].inject({}) { |h, (k, v)| h[k] = account.send(v); h },
        "custom" => LEAD_INFO["custom"].inject({}) { |h, (k, v)| h[k] = account.send(v); h }.merge(
          {'string--Associated--Accounts' => @associated_account_id_list })
      }
    end

    def subscription_info(subscription)
      {
        'custom' => SUBSCRIPTION_INFO["custom"].inject({}) { |h, (k, v)| h[k] = AUTOPILOT_STATES[subscription.send(v).to_s] || subscription.send(v).to_s; h }.merge(
          {"string--Product" => PRODUCT_NAME, 
            'date--Signup--Date' => subscription.created_at.strftime("%Y-%m-%d"), 
            'date--Next--Renewal--Date' => subscription.next_renewal_at.strftime("%Y-%m-%d")})
      }
    end

    def signup_info(metrics)
      {
        'default' => SIGNUP_INFO["default"].inject({}) { |h, (k, v)| h[k] = metrics.send(v).to_s; h },
        'custom' => SIGNUP_INFO["custom"].inject({}) { |h, (k, v)| h[k] = metrics.send(v).to_s; h }.merge(
          {"string--Signup--ID" => @signup_id})
      }
    end

    def make_api(req_type, url, data={})
      if req_type.to_s == REQUEST_TYPES[:get]
        RestClient.send(req_type, url, AUTOPILOT_CREDENTIALS)
      elsif req_type.to_s == REQUEST_TYPES[:post]
        RestClient.send(req_type, url, data, AUTOPILOT_CREDENTIALS)
      end
    end
end