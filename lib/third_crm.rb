class ThirdCRM
  PRODUCT_NAME = "Freshdesk"

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
      'custom' => {'string--Plan' => :plan_name, 'float--Monthly--Revenue' => :amount, 'integer--Agent--Count' => :agent_limit, 
        'string--Customer--Status' => :state, 'string--Contact--Status' => :state}
    }

  def add_signup_data(account, options = {})
    @signup_id = options[:signup_id]
    add_lead_to_crm(lead_info(account))    
  end

  def lead_info(account)
    account_info = user_info(account)
    subscription_info = subscription_info(account.subscription)
    misc = account.conversion_metric ? signup_info(account.conversion_metric) : {'default' => {}, 'custom' => {}}
    lead_details = account_info['default'].merge(misc['default'])
    lead_details["custom"] = account_info['custom'].merge(subscription_info['custom']).merge(misc['custom'])
    {"contact" => lead_details}
  end


  private

    def add_lead_to_crm(lead_record)
      response = RestClient.post AUTOPILOT_TOKENS['contact_url'], lead_record.to_json, {"autopilotapikey" => AUTOPILOT_TOKENS['access_key'], "Content-Type" => 'application/json'}
      person_id = JSON.parse(response)['contact_id']
      trigger_url = AUTOPILOT_TOKENS['trigger_url']  % {:trigger_code => AUTOPILOT_TOKENS['trigger_code'], :person_id => person_id}
      RestClient.post trigger_url,{} , {"autopilotapikey" => AUTOPILOT_TOKENS['access_key'], "Content-Type" => 'application/json'}
    end

    def user_info(account)
      {
        "default" => LEAD_INFO["default"].inject({}) { |h, (k, v)| h[k] = account.send(v); h },
        "custom" => LEAD_INFO["custom"].inject({}) { |h, (k, v)| h[k] = account.send(v); h } 
      }
    end

    def subscription_info(subscription)
      {
        'custom' => SUBSCRIPTION_INFO["custom"].inject({}) { |h, (k, v)| h[k] = subscription.send(v).to_s; h }.merge(
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
end