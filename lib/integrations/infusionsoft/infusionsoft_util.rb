module Integrations::Infusionsoft::InfusionsoftUtil
  include Integrations::OauthHelper
  include Integrations::Infusionsoft::Constant
  include Integrations::Constants
  
def get_is_object_metadata(form_id)
  oauth_token = @installed_app.configs[:inputs]['oauth_token']
  hrp = HttpRequestProxy.new
  req_params = {:user_agent => request.headers['HTTP_USER_AGENT']}
  req_body = REQUEST_BODY % {:form_id =>form_id.to_s}
  params = {:domain => DOMAIN_URL, 
            :method => :post, 
            :rest_url => METADATA_REST_URL + oauth_token,        
            :content_type => "application/xml", 
            :body => req_body}
  response_data = hrp.fetch_using_req_params params, req_params
  if response_data[:status] == 401
    new_oauth_token = get_new_access_token        
    params[:rest_url] = METADATA_REST_URL + new_oauth_token
    response_data = hrp.fetch_using_req_params params, req_params
  end
  if response_data[:status] != 200
    return
  end
  field_labels = handle_response_data(response_data, form_id)
  form_id == CONTACT_FORMID ? field_labels.merge!(CONTACT_FIELDS) : field_labels.merge!(COMPANY_FIELDS)
  Hash[field_labels.sort]
end

  private
  def get_new_access_token
     access_token = get_oauth2_access_token(@installed_app.application.oauth_provider, @installed_app.configs[:inputs]['refresh_token'], APP_NAMES[:infusionsoft])
     @installed_app[:configs][:inputs]['oauth_token'] = access_token.token
     @installed_app[:configs][:inputs]['refresh_token'] = access_token.refresh_token
     @installed_app.save #updating the installed app with new tokens
     access_token.token 
  end 

  def handle_response_data(response_data, form_id)
    response_hash = JSON.parse(response_data[:text])
    response_array = response_hash['methodResponse']['params']['param']['value']['array']['data'].try(:[], "value")
    
    response_array = Array.wrap(response_array)
    field_labels = Hash.new
    custom_fields = Array.new
    data_types = Array.new

    response_array.each do |value|
      field_members = value['struct']['member']
      field_value=label_value=data_type=""
      field_members.each do |member|
        if member['name'] == FIELD_NAME
          field_value = "_"+member['value']
        elsif member['name'] == FIELD_LABEL
          label_value = member['value']
        elsif member['name'] == DATATYPE
          data_type = member['value']['i4']
        end
      end
      if data_type.present? && EXCLUDED_DATA_TYPES.exclude?(data_type)
        custom_fields.push(field_value)
        data_types.push(data_type)
        field_labels[label_value] = field_value
      end
    end
    
    if form_id == CONTACT_FORMID
      @fields['contact_custom_fields'] = custom_fields
      @fields['contact_data_types'] =   data_types
    else
      @fields['account_custom_fields'] = custom_fields
      @fields['account_data_types'] = data_types
    end
    field_labels
  end
end