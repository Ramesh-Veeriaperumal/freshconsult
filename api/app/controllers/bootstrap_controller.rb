class BootstrapController < ApiApplicationController

  def meta_info
    date_format = Account::DATEFORMATS[current_account.account_additional_settings.date_format]
    @data_date_format = Account::DATA_DATEFORMATS[date_format]
    @current_timezone = ActiveSupport::TimeZone.new(current_user.time_zone || current_account.time_zone).tzinfo.identifier
  end

  private

    #overriding this methods from api_application_controller.rb
    def scoper
      current_user
    end

    def load_object(items = scoper)
      # This method has been overridden to avoid pagination.
      @agent = current_user.agent
    end

end