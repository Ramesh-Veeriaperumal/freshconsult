module Integrations::SalesforceUtil
    def fetch_sf_contact_fields(config_hash)
      fields_hash = get_object_metadata("Contact", config_hash)
      available_contact_fields = Array.new
      fields_hash.each{ |field|
        DEFAULT_SF_CONTACT_FIELDS.each{|reqField|
            available_contact_fields.push(reqField) if(field["name"] == reqField)
        }
      }
      return available_contact_fields.join(",")
    end

  
    def fetch_sf_lead_fields(config_hash)
      fields_hash = get_object_metadata("Lead", config_hash)
      available_lead_fields = Array.new
      fields_hash.each{ |field|
        DEFAULT_SF_LEAD_FIELDS.each{|reqField|
            available_lead_fields.push(reqField) if(field["name"] == reqField)
        }
      }
      return available_lead_fields.join(",")
    end

  private  
    def get_object_metadata(sObject, config_hash)
      hrp = HttpRequestProxy.new
      reqParams = {}
      reqParams[:user_agent] = request.headers['HTTP_USER_AGENT']
      reqParams[:auth_header] = "OAuth " +  config_hash['oauth_token']
      params[:domain] = config_hash['instance_url']
      params[:method] = "get"
      params[:ssl_enabled] = "false"
      params[:resource] = "services/data/v20.0/sobjects/#{sObject}/describe"
      params[:content_type] = "application/json"
      params[:accept_type] = "application/json"
      fields_meta_data = hrp.fetch_using_req_params params, reqParams
      fields_hash = JSON.parse(fields_meta_data[:text])
      fields_hash["fields"]
    end


  DEFAULT_SF_CONTACT_FIELDS = ["Id", "MobilePhone", "Phone", "Department", "Email", "Name", "MailingCity", "MailingCountry", "MailingState", "MailingStreet", "Title"]
  DEFAULT_SF_LEAD_FIELDS = ["Id", "City", "Company", "IsConverted", "Country", "Name", "Phone", "MobilePhone", "State", "Status", "Street", "Title"]


end