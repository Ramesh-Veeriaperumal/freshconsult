class ApiBusinessHoursController < ApiApplicationController
  private

    def load_objects
      items = multiple_business_hours_enabled? ? scoper.order(:name) : [Group.default_business_calendar]
      super(items)
    end

    def load_object
      unless default_business_hour?
        if multiple_business_hours_enabled?
          super
        else
          render_request_error(:require_feature, 403, feature: 'multiple_business_hours'.titleize)
        end
      end
    end

    def scoper
      current_account.business_calendar
    end

    def default_business_hour?
      return @item if defined?(@item)
      bc = Group.default_business_calendar
      @item = bc if params[:id] == bc.id.to_s
    end

    def multiple_business_hours_enabled?
      Account.current.multiple_business_hours_enabled?
    end
end
