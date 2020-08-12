class Admin::HolidaysController < ApiApplicationController
  include Admin::HolidaysConstants

  def show
    google_service_obj = IntegrationServices::Services::GoogleService.new(nil, { 'calendar_id' => @calendar_id }, user_agent: request.user_agent)
    service_response = google_service_obj.receive('list_holidays')
    if service_response[:error].blank?
      @items = service_response[:holidays]
    else
      Rails.logger.info "Unable to fetch holidays for #{@calendar_id}, Trace: #{service_response[:error_message]}"
      @items = []
    end
  end

  private

    def load_object
      @calendar_id = HOLIDAYS_WITH_CODES_MAPPING[params[:id].upcase]
      log_and_render_404 && return unless @calendar_id
      @calendar_id += GOOGLE_CALENDAR_ID_SUFFIX
    end

    def launch_party_name
      FeatureConstants::EMBERIZE_BUSINESS_HOURS
    end
end
