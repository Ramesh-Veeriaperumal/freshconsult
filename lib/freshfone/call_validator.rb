module Freshfone::CallValidator

  def authorized_country?(phone_number, current_account)
    begin
    country_obj = GlobalPhone.parse(phone_number)
    country = country_obj.valid? ? country_obj.territory.name : nil
    rescue Exception => e 
    	Rails.logger.debug "Exception when validating country for whitelist :: account :: #{current_account.id}:: "
    	Rails.logger.debug "#{e.message}\n#{e.backtrace.join("\n\t")}"
    end
    country_whitelisted = Freshfone::Config::WHITELIST_NUMBERS[country]
    if country_whitelisted.blank? || !country_whitelisted["enabled"]  
      country_whitelisted = current_account.freshfone_whitelist_country.find_by_country(country)
    end
    country_whitelisted.present?
  end

  def enough_credit?
    !current_account.freshfone_credit.below_calling_threshold?
  end

  def validate_outgoing
    status = :ok
    if !enough_credit?
      status = :low_credit
    elsif !authorized_country?(params[:phone_number],current_account)
      status = :dial_restricted_country
    end
    status
  end
end