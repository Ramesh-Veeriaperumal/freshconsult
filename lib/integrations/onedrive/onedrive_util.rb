module Integrations::Onedrive::OnedriveUtil
include Integrations::Onedrive::Constant
    
  def get_access_token  
    HTTParty.post(ONEDRIVE_REST_API,{:body => {'client_id'=> Integrations::ONEDRIVE_CLIENT_ID,
     'redirect_uri' =>"#{AppConfig['integrations_url'][Rails.env]}/integrations/onedrive/callback", 
     'client_secret' => Integrations::ONEDRIVE_CLIENT_SECRET, 'code' => params["code"], 
     'grant_type' =>'authorization_code'}, :timeout => 5})
  end

  def create_web_url  
      onedrive_access_token = Rack::Utils.parse_nested_query(cookies["wl_auth"])["access_token"]
      response = HTTParty.post("#{ONEDRIVE_VIEW_API}/v1.0/drive/items/#{params["res_id"]}/action.createLink",
       {:body => { "type" => "view"}.to_json,:headers => {"Authorization" =>"Bearer #{onedrive_access_token}",
        "Host"=> ONEDRIVE_HOST,"X-Target-URI"=> ONEDRIVE_VIEW_API,"Content-Type"=>"application/json"},
       :timeout => 5}) 
      {:url => response["link"]["webUrl"], :status => "success" }
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error occoured while creating view link for Onedrive"}})
      Rails.logger.error "#{e}"
      {:url => "", :status => "false" }
  end

end


