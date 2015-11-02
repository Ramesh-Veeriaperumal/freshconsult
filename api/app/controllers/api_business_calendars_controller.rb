class ApiBusinessCalendarsController < ApiApplicationController
  private

    def feature_name
      FeatureConstants::BUSINESS_CALENDAR
    end

    def load_objects
      super(scoper.order(:name))
    end

    def scoper
      current_account.business_calendar
    end
end
