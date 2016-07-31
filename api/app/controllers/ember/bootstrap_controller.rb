class Ember::BootstrapController < ApiApplicationController

  
  def index
    @agent = current_user.agent
    date_format = Account::DATEFORMATS[current_account.account_additional_settings.date_format]
    @data_date_format = Account::DATA_DATEFORMATS[date_format]
    @current_timezone = ActiveSupport::TimeZone.new(current_user.time_zone || current_account.time_zone).tzinfo.identifier
    
    response.api_meta = {
      csrf_token: self.send(:form_authenticity_token)
    }
  end

end