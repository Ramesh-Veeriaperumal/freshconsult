module Integrations::RemoteConfigurations::Seoshop

  def validate_seoshop(key_hash)
    if timestamp_valid?
      if !seoshop_signature_valid?(key_hash)
        logger.debug "SEOshop Error::Signature mismatch"
        redirect_to '/500.html'
      end
    else
      logger.debug "SEOshop Error::Timestamp exceeded 5 minutes"
      redirect_to '/403.html'
    end
  end

  def set_seoshop_params
    if(params[:language] && params[:token])
      app_params = {}
      app_params[:language] = params[:language]
      app_params[:token] = params[:token]
      app_params.inspect
    else
      params[:app_params]
    end
  end

  def process_seoshop(domain, account_id)
    if(params[:id] == "install")
      install_application(domain, account_id)
    elsif(params[:id] == "uninstall")
      uninstall_application(domain, account_id)
    end
  end

  def build_seoshop_configs(key_hash)
    configs = {}
    configs[:inputs] = {}
    configs[:inputs]["api_key"] = key_hash["api_key"]
    app_params = eval(params[:app_params])
    configs[:inputs]["api_secret"] = Digest::MD5.hexdigest(app_params[:token] + key_hash["api_secret"])
    configs[:inputs]["language"] = app_params[:language]
    configs
  end

  def seoshop_signature_valid?(key_hash)
    shop_params = {}
    sign = ''
    [:language, :shop_id, :timestamp, :token].each do |key|
      if (params[key].nil? || params[key].empty?)
        logger.debug "For SEO Shop param #{key} is missing for signature validation"
      else
        shop_params[key] = params[key]
      end
    end
    shop_params.sort.each{|k, v| sign += "#{k}=#{v}"}
    Digest::MD5.hexdigest(sign + key_hash["api_secret"]) == params["signature"]
  end

  def timestamp_valid?
    if(Rails.env.test?)
      return true
    end
    (Time.now.to_i - params[:timestamp].to_i) < 300
  end
end