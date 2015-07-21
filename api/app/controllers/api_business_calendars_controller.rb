class ApiBusinessCalendarsController < ApiApplicationController
  before_filter :load_object, except: [:index, :route_not_found]
  before_filter :load_objects, only: [:index]
  before_filter :load_association, only: [:show]

  private

    def feature_name
      FeatureConstants::BUSINESS_CALENDAR
    end

    def scoper
      current_account.business_calendar
    end
end
