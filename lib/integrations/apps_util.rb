require 'openssl'
require 'base64'

module Integrations::AppsUtil
  include RedisKeys
  
  def get_installed_apps
    @installed_applications = Integrations::InstalledApplication.find(:all, :conditions => ["account_id = ?", current_account])
  end

  def execute(clazz_str, method_str, args=[])
    unless clazz_str.blank?
      obj = clazz_str.constantize
      obj = obj.new unless obj.respond_to?(method_str)
      if obj.respond_to?(method_str)
        obj.send(method_str, args)
      else
        raise "#{clazz_str} is not responding to #{method_str}."
      end
    end
  end

  def get_cached_values(ticket_id)
    cache_val = get_key("INTEGRATIONS_LOGMEIN:#{current_account.id}:#{ticket_id}")
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

  def construct_params_for_http(method,rest_url,body=nil)
    fieldData = {
      :username => @installed_app.configs_username,
      :password => @installed_app.configsdecrypt_password,
      :domain => @installed_app.configs_domain,
      :rest_url => rest_url,
      :method => method
    }
    if(body)
      fieldData[:body] = body
    end
    fieldData
  end

  def make_rest_call(params, request)
    @http_request_proxy.fetch(params, request)
  end

  def redirect_back_using_cookie(request, default_uri=root_path)
    redirect_uri = request.cookies.fetch('return_uri', default_uri)
    cookies.delete('return_uri')
    puts "redirect_uri: #{redirect_uri}"
    redirect_to redirect_uri
  end

end
