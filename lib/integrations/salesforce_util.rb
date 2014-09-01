module Integrations::SalesforceUtil
    def fetch_sf_contact_fields(oauth_token, instance_url)
      get_object_metadata(:Contact, oauth_token, instance_url)
    end

    def fetch_sf_lead_fields(oauth_token, instance_url)
      get_object_metadata(:Lead, oauth_token, instance_url)
    end

    def fetch_sf_account_fields(oauth_token, instance_url)
      get_object_metadata(:Account, oauth_token, instance_url)
    end

  private  
    def get_object_metadata(sObject, oauth_token, instance_url)
      hrp = HttpRequestProxy.new
      reqParams = {:user_agent => request.headers['HTTP_USER_AGENT'], :auth_header => "OAuth " + oauth_token}
      params = {:domain => instance_url, :method => "get", :ssl_enabled => "false", :rest_url => "services/data/v20.0/sobjects/#{sObject.to_s}/describe", :content_type => "application/json", :accept_type => "application/json"}
      fields_meta_data = hrp.fetch_using_req_params params, reqParams
      fields_hash = JSON.parse(fields_meta_data[:text])
      fields_hash = fields_hash["fields"]

      field_labels = Hash.new
      fields_hash.each{ |field|
         field_labels[field["name"]]= field["label"]
      }
      #Adding an Address field intentionally to group [MailingStreet,City,Country,PostalCode].
      #If the user selects Address in dropdown,full address will be shown formed by above fields.
      field_labels.merge!("Address"=>"Address")
    end

end