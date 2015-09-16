module Freshfone::CallValidator
  include Redis::RedisKeys
  include Redis::IntegrationsRedis

  BEYOND_THRESHOLD_PARALLEL_INCOMING = 3 # parallel incomings allowed beyond safe_threshold
  BEYOND_THRESHOLD_PARALLEL_OUTGOING = 1 # parallel incomings allowed beyond safe_threshold

  #VOICE PRECONDITIONS

  def preconditions?
    return false if current_account.freshfone_credit.below_safe_threshold?
    return false if outgoing? && !authorized_country?(params[:PhoneNumber], current_account)
    return outgoing? ? outgoing_permissible? : incoming_permissible?
    true
  end

  def outgoing? #used by voice_url
    params[:type] == "outgoing"
  end

  #VOICE PRECONDITIONS END

  def authorized_country?(phone_number, current_account)
    begin
    country_obj = GlobalPhone.parse(phone_number)
    return true if country_obj.nil? && isPreviewOrRecord?
    country = country_obj.present? ? country_obj.territory.name : nil
    rescue Exception => e 
    	Rails.logger.debug "Exception when validating country for whitelist :: account :: #{current_account.id}:: "
    	Rails.logger.debug "#{e.message}\n#{e.backtrace.join("\n\t")}"
    end
    if country.present?
      country_whitelisted = Freshfone::Config::WHITELIST_NUMBERS[country] 
      if country_whitelisted.blank? || !country_whitelisted["enabled"]  
        country_whitelisted = current_account.freshfone_whitelist_country.find_by_country(country)
      end
      country_whitelisted.present?
    else
      return country.present? 
    end
  end

  def enough_credit?
    !current_account.freshfone_credit.below_calling_threshold?
  end

  def validate_outgoing
    status = :ok
    if !enough_credit?
      status = :low_credit
    elsif isOutgoing? && !isPreviewOrRecord? && !authorized_country?(params[:phone_number],current_account)
      status = :dial_restricted_country
    end
    status
  end

  def isOutgoing? #used from client before initiating the call
    return params[:is_country].to_bool if params[:is_country].present?
    false
  end

  def isPreviewOrRecord?
    return params[:preview].to_bool if params[:preview].present?
    return params[:record].to_bool if params[:record].present?
    false
  end

  private
    def calls_count
      @calls_count ||= begin
        key = FRESHFONE_CALLS_BEYOND_THRESHOLD % { :account_id => current_account.id }
        get_key(key).to_i
      end
    end

    def outgoing_permissible?
      (calls_count & 15) < BEYOND_THRESHOLD_PARALLEL_OUTGOING
    end

    def incoming_permissible?
      (calls_count >> 4) < BEYOND_THRESHOLD_PARALLEL_INCOMING
    end
end