module Integrations::RemoteConfigurations::Seoshop

  def validate_seoshop(key_hash)
    if timestamp_valid?
      if !seoshop_signature_valid?(key_hash)
        show_notice "Could not validate the application credentials..... Please try again....."
      end
    else
      show_notice "Some error occurred while installing SEO Shop in Freshdesk..... please try again ...... "
    end
  end

  def process_seoshop(domain, account_id)
    if(params[:app_params]["id"] == "install")
      install_application(domain, account_id)
    elsif(params[:app_params]["id"] == "uninstall")
      uninstall_application(domain, account_id)
    end
  end

  def build_seoshop_configs(key_hash)
    configs = {}
    configs[:inputs] = {}
    configs[:inputs]["api_key"] = key_hash["api_key"]
    configs[:inputs]["api_secret"] = Digest::MD5.hexdigest(params[:app_params]["token"] + key_hash["api_secret"])
    configs[:inputs]["language"] = params[:app_params]["language"]
    configs
  end

  def seoshop_signature_valid?(key_hash)
    shop_params = {}
    sign = ''
    ["language", "shop_id", "timestamp", "token"].each do |key|
      if (params[:app_params][key].nil? || params[:app_params][key].empty?)
        logger.debug "For SEO Shop param #{key} is missing for signature validation"
      else
        shop_params[key] = params[:app_params][key]
      end
    end
    shop_params.sort.each{|k, v| sign += "#{k}=#{v}"}
    Digest::MD5.hexdigest(sign + key_hash["api_secret"]) == params[:app_params]["signature"]
  end

  def timestamp_valid?
    if(Rails.env.test?)
      return true
    end
    (Time.now.to_i - params[:app_params]["timestamp"].to_i) < 300
  end
end