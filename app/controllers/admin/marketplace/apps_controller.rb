class Admin::Marketplace::AppsController < Admin::AdminController
  include Marketplace::GalleryConstants

  before_filter :access_denied, unless: :marketplace_feature_enabled?

  def index
    params_to_encrypt = default_mkp_params
    additional_params = {
      pod: PodConfig['CURRENT_POD'],
      locale: current_user.language
    }

    Rails.logger.info("Render App Gallery for account #{current_account.id} and pod #{PodConfig['CURRENT_POD']}")

    if current_account.freshid_org_v2_enabled?
      Rails.logger.info("FreshId V2 params - #{current_account.organisation_domain}")
      params_to_encrypt = params_to_encrypt.merge(org: current_account.organisation_domain, organisation_id: current_account.organisation_id)
    elsif current_account.freshid_integration_enabled?
      Rails.logger.info('FreshId V1 - No params needed')
      # Do Nothing
      # No params needed
    else
      Rails.logger.info('FreshId not enabled')
      additional_params[:freshID] = false
    end
    iframe_params = encrypt(params_to_encrypt.to_json)
    iframe_url = build_marketplace_url(iframe_params, additional_params)
    iframe_url = add_tenant_details_to_url(iframe_url)
    render json: { url: iframe_url }
  end

  private

    def freshid_enabled?
      current_account.freshid_org_v2_enabled? || current_account.freshid_integration_enabled?
    end

    def build_marketplace_url(iframe_params, additional_params)
      "#{MarketplaceConfig::GALLERY_URL}/marketplace?params=#{iframe_params}&#{additional_params.to_query}"
    end

    def add_tenant_details_to_url(iframe_url)
      authorization = freshid_enabled? ? current_account.domain : DEFAULT_AUTH
      tenant_details = "#{MarketplaceConfig::TENANT_NAME}-#{authorization}."
      "#{MarketplaceConfig::GALLERY_PROTOCOL}#{tenant_details}#{iframe_url}"
    end

    def marketplace_feature_enabled?
      current_account.marketplace_gallery_enabled?
    end

    def default_mkp_params
      host = Rails.env.development? ? request.host_with_port : request.host
      {
        account_id: current_account.id,
        user_id: current_user.id,
        product_id: Marketplace::Constants::PRODUCT_ID,
        product_name: Marketplace::Constants::PRODUCT_NAME,
        account_domain: host,
        protocol: request.protocol,
        isCustomAppsEnabled: current_account.custom_apps_enabled?
      }
    end

    def encrypt(data)
      aes = OpenSSL::Cipher::Cipher.new('AES-256-CTR')
      aes.encrypt
      aes.key = MarketplaceConfig::MARKETPLACE_CIPHER_KEY
      aes.iv  = MarketplaceConfig::MARKETPLACE_CIPHER_IV
      encrypted_data = (aes.update(data) + aes.final).unpack('H*').first
      CGI.escape(encrypted_data)
    end
end
