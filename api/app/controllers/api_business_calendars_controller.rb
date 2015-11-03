class ApiBusinessCalendarsController < ApiApplicationController
  private

    def feature_name
      FeatureConstants::BUSINESS_CALENDAR
    end

    def load_objects
      (current_account.features_included?(:multiple_business_hours)) ? (super(scoper.order(:name))) : (Array.wrap default_business_calendar)
    end

    def default_business_calendar
      current_account.business_calendar.default.first
    end

    def scoper
      current_account.business_calendar
    end
end
