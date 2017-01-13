module Ember
  class BootstrapController < ApiApplicationController

    COLLECTION_RESPONSE_FOR = []
    def index
      @agent = current_user.agent
      date_format = Account::DATEFORMATS[current_account.account_additional_settings.date_format]
      @data_date_format = Account::DATA_DATEFORMATS[date_format]
      @current_timezone = ActiveSupport::TimeZone.new(current_user.time_zone || current_account.time_zone).tzinfo.identifier
      @avatar_hash = ContactDecorator.new(current_user, {}).avatar_hash
      @survey_in_specific_emails = current_account.new_survey_enabled? && current_account.active_custom_survey_from_cache.try(:send_while) == Survey::SPECIFIC_EMAIL_RESPONSE
      response.api_meta = {
        csrf_token: self.send(:form_authenticity_token)
      }
    end
  end
end
