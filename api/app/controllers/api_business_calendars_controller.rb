class ApiBusinessCalendarsController < ApiApplicationController

  private

    def feature_name
      FeatureConstants::BUSINESS_CALENDAR
    end

    def scoper
      current_account.business_calendar
    end
end
