class Ember::BootstrapController < ApiApplicationController

  COLLECTION_RESPONSE_FOR = []
  def index
    @agent = current_user.agent
    date_format = Account::DATEFORMATS[current_account.account_additional_settings.date_format]
    @data_date_format = Account::DATA_DATEFORMATS[date_format]
    @current_timezone = ActiveSupport::TimeZone.new(current_user.time_zone || current_account.time_zone).tzinfo.identifier
    @avatar_hash = ContactDecorator.new(current_user, {}).avatar_hash
    response.api_meta = {
      csrf_token: self.send(:form_authenticity_token)
    }
  end

end