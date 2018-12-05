class Users::DetectLanguage < BaseWorker
  include Redis::RedisKeys
  include Redis::OthersRedis

  sidekiq_options :queue => :detect_user_language, 
                  :retry => 0, 
                  :backtrace => true, 
                  :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    return unless args[:user_id].present? && args[:text].present?
    account = Account.current
    @user   = account.all_users.find(args[:user_id])
    @text   = args[:text]

    if account.compact_lang_detection_enabled?
      detect_lang_from_cld
    else
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
      if en_via_cld?
        Rails.logger.debug "successfully detected en via cld text:: #{@text}, account_id:: #{@account.id}"
        @user.language = "en"
        @user.save!
      else
        Rails.logger.debug "cld non english text:: #{@text}, account_id:: #{@account.id}"
        Helpdesk::DetectUserLanguage.set_user_language!(@user, @text)
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

    def text_available_from_cache?
      @language = get_others_redis_key(DETECT_USER_LANGUAGE % { :text => @text })
    end

    def assign_user_language
      Rails.logger.info "User language from cache -text #{@text} -language #{@language} -acc #{Account.current.id} -usr #{@user.email}"
      @user.language = (I18n.available_locales_with_name.map{
        |lang,sym| sym.to_s }.include? @language) ? @language : @user.account.language
    end

    def en_via_cld?
      detected_language = CLD.detect_language(@text)
      Rails.logger.info "Detected language:: #{detected_language.inspect}, text:: #{@text}"
      detected_language[:reliable] && (detected_language[:code] == "en")
    rescue Exception => e
      Rails.logger.debug "Exception in CLD detection:: #{e.message}"
      false
    end
end
