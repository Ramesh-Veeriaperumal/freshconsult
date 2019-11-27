class Admin::Marketplace::AppsController < Admin::AdminController

  def index
    params_to_encrypt = default_mkp_params
    additional_params = { pod: PodConfig['CURRENT_POD'] }

    Rails.logger.info("Render App Gallery for account #{current_account.id} and pod #{PodConfig['CURRENT_POD']}")

    if current_account.freshid_org_v2_enabled?
      Rails.logger.info("FreshId V2 params - #{current_account.organisation_domain}")
      params_to_encrypt.merge({ org: current_account.organisation_domain })
    elsif current_account.freshid_integration_enabled?
      Rails.logger.info("FreshId V1 - No params needed")
      # Do Nothing
      # No params needed
    else
      Rails.logger.info("FreshId not enabled")
      additional_params.merge!({ freshID: false })
    end

    iframe_params = encrypt(params_to_encrypt.to_json)
    @gallery_iframe_url = "#{MarketplaceConfig::GALLERY_URL}/marketplace?params=#{iframe_params}&#{additional_params.to_query}"
  end

  private

    def default_mkp_params
      {
        account_id: current_account.id,
        user_id: current_user.id,
        product_id: Marketplace::Constants::PRODUCT_ID,
        product_name: Marketplace::Constants::PRODUCT_NAME,
        account_domain: "#{request.protocol}#{request.host_with_port}",
        isCustomAppsEnabled: current_account.custom_apps_enabled?
      }
    end

    def encrypt(data)
      aes = OpenSSL::Cipher::Cipher.new('AES-256-CTR')
      aes.encrypt
      aes.key = MarketplaceConfig::MARKETPLACE_CIPHER_KEY
      aes.iv  = MarketplaceConfig::MARKETPLACE_CIPHER_IV
      encrypted_data = (aes.update(data) + aes.final).unpack('H*').first
      URI.encode(encrypted_data)
    end
end
