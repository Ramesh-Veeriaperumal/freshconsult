class Users::DetectLanguage < BaseWorker
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Cache::LocalCache

  FD_EMAIL_SERVICE = YAML.load_file(Rails.root.join('config', 'fd_email_service.yml'))[Rails.env]
  EMAIL_SERVICE_AUTHORISATION_KEY = FD_EMAIL_SERVICE['lang_key']
  EMAIL_SERVICE_HOST = FD_EMAIL_SERVICE['lang_host']
  LANGUAGE_DETECT_URL = FD_EMAIL_SERVICE['lang_detect_path']

  sidekiq_options queue: :detect_user_language,
                  retry: 0,
                  failures: :exhausted

  def perform(args)
    args.symbolize_keys!
    return unless args[:user_id].present? && args[:text].present?
    account = Account.current
    @user   = account.all_users.find(args[:user_id])
    @text   = args[:text]
    if account.compact_lang_detection_enabled?
      detect_lang_from_cld
    elsif account.detect_lang_from_email_service_enabled?
      set_lang_via_email_service
    else
      @text.squish.split.first(15).join(' ')
      detect_lang_from_google
    end
  rescue => e
    Rails.logger.error("DetectLanguage: account #{account.id} - #{args} - #{e.message} #{e.backtrace.to_a.join("\n")}")
    NewRelic::Agent.notice_error(e,{:description => "DetectLanguage: account #{account.id} - #{args}"})
  ensure
    if @user && @user.language.nil?
      @user.language = @user.account.language
      Rails.logger.info "DetectLanguage::user #{args} #{@user.errors}" unless @user.save
    end
  end

  private

    def detect_lang_from_cld
      if lang_via_cld
        assign_user_language
        @user.save!
      else
        Rails.logger.debug "unable to get via cld text:: #{@text}, account_id:: #{Account.current.id}"
        detect_lang_from_google
      end
    end

    def detect_lang_from_google
      if text_available_from_cache?
        assign_user_language
        @user.save!
      else
        Helpdesk::DetectUserLanguage.set_user_language!(@user, @text)
      end
    end

    def detect_lang_from_email_service
      response = RestClient::Request.execute(
        method: :post,
        url: "#{EMAIL_SERVICE_HOST}/#{LANGUAGE_DETECT_URL}",
        payload: { text: @text }.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => EMAIL_SERVICE_AUTHORISATION_KEY
        }
      )
      response_body = JSON.parse(response.body)
      if response.code == 200 && response_body['Status'] == 'Success'
        language = response_body['data']['detections'].flatten.last['language']
        Rails.logger.info "Detected language from email_service language: #{language} - text: #{@text} -Account_id: #{Account.current.id}"
      end
      language
    end

    def set_lang_via_email_service
      @user.language = @user.account.language
      language = detect_lang_from_email_service
      @user.language = (I18n.available_locales_with_name.map { |lang, sym| sym.to_s }.include? language) ? language : @user.account.language
      @user.save!
    end

    def text_available_from_cache?
      @language = get_others_redis_key(DETECT_USER_LANGUAGE % { :text => @text })
    end

    def assign_user_language
      Rails.logger.info "User language -text #{@text} -language #{@language} -acc #{Account.current.id} -usr #{@user.email}"
      @user.language = (I18n.available_locales_with_name.map{
        |lang,sym| sym.to_s }.include? @language) ? @language : @user.account.language
    end

    def lang_via_cld
      detected_language = CLD.detect_language(@text)
      Rails.logger.info "Detected language:: #{detected_language.inspect}, text:: #{@text}"
      detected_language[:reliable] && lang_exists_in_redis?(detected_language[:code])
    rescue Exception => e
      Rails.logger.debug "Exception in CLD detection:: #{e.message}"
      false
    end

    def lang_exists_in_redis?(lang_code)
      lang_hash = fetch_lcached_hash(CLD_FD_LANGUAGE_MAPPING, 7.days)
      @language = lang_hash.present? ? lang_hash[lang_code] : nil
    end
end
