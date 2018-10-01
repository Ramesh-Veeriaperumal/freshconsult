require 'openssl'
require 'base64'

module Integrations::AppsUtil
  include Redis::RedisKeys
  include Redis::IntegrationsRedis

  SPL_CHAR_ESCAPE = { '&' => '\\u0026', "'" => "''", '/' => '\\u002f', '"' => "\\u0022", '+' => '\\u002b', "#" => '\\u0023', "\\" => '\\u005c\\u005c' }
  
  def get_installed_apps
    @installed_applications = Account.current.installed_applications.includes(:application).all
  end

  def execute(clazz_str, method_str, args=[])
    unless clazz_str.blank?
      obj = clazz_str.constantize
      obj = obj.new unless obj.respond_to?(method_str)
      if obj.respond_to?(method_str)
        obj.safe_send(method_str, args)
      else
        raise "#{clazz_str} is not responding to #{method_str}."
      end
    end
  end

  def execute_service(clazz_str, method_str, installed_app, args=[])
    unless clazz_str.blank?
      obj = clazz_str.constantize
      obj = obj.new(installed_app, args)
      obj.receive(method_str)
    end
  end

  def get_cached_values(ticket_id)
    cache_val = get_integ_redis_key("INTEGRATIONS_LOGMEIN:#{current_account.id}:#{ticket_id}")
    (cache_val.blank?) ? {} : JSON.parse(cache_val)
  end

  def get_md5_secret
    Digest::MD5.hexdigest(((DateTime.now.to_f * 1000).to_i).to_s)
  end

  def replace_liquid_values(liquid_template, data)
    if liquid_template.class == Hash
      liquid_template.map {|key, value| liquid_template[key] = replace_liquid_values(value, data)}
    elsif liquid_template.class == Array
      liquid_template.each_index {|i| liquid_template[i] = replace_liquid_values(liquid_template[i], data)}
    elsif liquid_template.class == String
      data = data.attributes if data.respond_to? :attributes
      Liquid::Template.parse(liquid_template).render(data)
    end
  end


  def redirect_back_using_cookie(request, default_uri=root_path)
    redirect_uri = request.cookies.fetch('return_uri', default_uri)
    cookies.delete('return_uri')
    puts "redirect_uri: #{redirect_uri}"
    redirect_to redirect_uri
  end


  def check_customer_app_access app_name
    return true if current_user && current_user.customer? 
    render :json => { :error => "Access Denied" }, :status => 403
  end

  def check_agent_app_access app_name
    return true if current_user && current_user.agent?
    render :json => { :error => "Access Denied" }, :status => 403
  end

  def spl_char_replace company_name
    company_name = company_name.to_s.gsub(/[&\'"+#\/\\]/, SPL_CHAR_ESCAPE)
  end

  def get_zohocrm_pod api_key
    zoho_pods = Integrations::Constants::ZOHO_CRM_PODS
    (zoho_api_error? zoho_pods[:us], api_key) ? ( (zoho_api_error? zoho_pods[:eu], api_key) ? zoho_pods[:us] : zoho_pods[:eu] ) : zoho_pods[:us]
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error in checking the Zoho Domain: #{e}", :account_id => current_account.id}})
    zoho_pods[:us]
  end

  def zoho_api_error? domain, api_key
    hrp = HttpRequestProxy.new
    params = { :domain => domain, :ssl_enabled => true, :rest_url => "crm/private/json/Contacts/searchRecords?scope=crmapi&selectColumns=All&criteria=(Email:sample@freshdesk.com)&authtoken=#{api_key}"}
    requestParams = { :method => "get", :user_agent => "_" }
    response = hrp.fetch_using_req_params(params, requestParams)
    response_text = JSON.parse response[:text]
    response_text["response"]["error"].present?
  end
end
