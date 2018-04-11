module Marketplace::InstExtControllerMethods
  include Marketplace::Constants

  private

  def get_iframe_params(iframe_settings)
    return iframe_default_params if iframe_settings["params"].blank?
    iframe_params = {}
    IFRAME_USER_PERMIT_PARAMS.each do |key, value|
      if iframe_settings["params"].include?(key)
        iframe_params[IFRAME_PERMIT_PARAMS[:user][value]] = current_user.safe_send(value)
      end
    end
    IFRAME_ACCOUNT_PERMIT_PARAMS.each do |key, value|
      if iframe_settings["params"].include?(key)
        iframe_params[IFRAME_PERMIT_PARAMS[:account][value]] = current_account.safe_send(value)
      end 
    end
    iframe_params.merge!(iframe_default_params)
  end

  def iframe_default_params
    {}.tap do |iframe_params|
      iframe_params[:a_id] = current_account.id
      iframe_params[:p_id] = PRODUCT_ID
      iframe_params[:e_id] = params[:extension_id]
      iframe_params[:v_id] = params[:version_id]
      iframe_params[:iat] = Time.zone.now.utc.iso8601
      iframe_params[:pod] = PodConfig['CURRENT_POD']
    end
  end

  def iframe_token(iframe_settings, iframe_params)
    return iframe_params if iframe_params.blank?
    rsa_public_key = OpenSSL::PKey::RSA.new(iframe_settings["key"])
    key = JOSE::JWK.from_key(rsa_public_key)
    iframe_params = iframe_params.to_json
    encryption_params = {}
    encryption_params["alg"] = IFRAME_ALLOWED_ENC_ALGO.include?(iframe_settings["algorithm"]) ? iframe_settings["algorithm"] : IFRAME_DEFAULT_ENC_ALGO
    encryption_params["enc"] = IFRAME_ALLOWED_ENC_TYPE.include?(iframe_settings["encryption"]) ? iframe_settings["encryption"] : IFRAME_DEFAULT_ENC_TYPE
    encryption_params["zip"] = IFRAME_DEFAULT_COMP_ALGO
    JOSE::JWE.block_encrypt(key, iframe_params, encryption_params).compact
  rescue => e
    exception_logger("Problem in generating the iframe payload: #{e.message}\n#{e.backtrace}")
    render_error_response(:internal_server_error) and return false
  end

  def configs_page_v2
    s3_id = params[:version_id].to_s.reverse
    @configs_url = "https://#{MarketplaceConfig::CDN_STATIC_ASSETS}/#{s3_id}/#{Marketplace::Constants::IPARAM_IFRAME}"
  end

  def oauth_iparams_page
    s3_id = params[:version_id].to_s.reverse
    oauth_iparams_url = "https://#{MarketplaceConfig::CDN_STATIC_ASSETS}/#{s3_id}/#{Marketplace::Constants::OAUTH_IPARAM}"
    @configs_page = open(oauth_iparams_url).read
  end

  def extension_has_config?
    render 'admin/marketplace/installed_extensions/configs' unless @extension['has_config']
  end
end
