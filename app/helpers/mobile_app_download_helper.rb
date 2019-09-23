
module MobileAppDownloadHelper
  mobile_onboarding_config = YAML.load_file(Rails.root.join('config', 'mobile_onboarding.yml'))
  MOBILE_REDIRECTION_BASE_URL = mobile_onboarding_config['mobile_redirection_base_url']
  ANDROID_APP_BUNDLE_ID = mobile_onboarding_config['android_app_bundle_id']
  IOS_APP_BUNDLE_ID = mobile_onboarding_config['ios_app_bundle_id']
  IOS_APP_STORE_ID = mobile_onboarding_config['ios_app_store_id']
  PLAY_STORE_URL = mobile_onboarding_config['playstore_store_url']
  APP_STORE_URL = mobile_onboarding_config['app_store_url']

  def skip_app_download_url
    @mobile_params[:url]
  end

  def app_helpdesk_url
    @mobile_params[:full_domain]
  end

  def redirection_url
    mobile_os == :ios ? APP_STORE_URL : PLAY_STORE_URL
  end

  def mobile_os
    @mobile_os ||= begin
      user_agent = request.env['HTTP_USER_AGENT'].downcase
      if user_agent['android'].present?
        :android
      elsif user_agent['iphone'].present? || user_agent['ipad'].present?
        :ios
      else
        :unknown
      end
    end
  end
end
