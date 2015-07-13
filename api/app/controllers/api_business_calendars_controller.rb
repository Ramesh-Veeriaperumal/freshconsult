class ApiBusinessCalendarsController < ApiApplicationController
  prepend_before_filter { |c| c.requires_feature :multiple_business_hours }

  private

    def scoper
      current_account.business_calendar
    end
end
