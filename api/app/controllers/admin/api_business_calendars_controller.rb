class Admin::ApiBusinessCalendarsController < ApiBusinessHoursController
  decorate_views

  def index
    super
  end

  def show
    super
  end

  private

    def decorator_options
      super({ groups: Account.current.groups_from_cache })
    end

    def constants_class
      :BusinessHourConstants.to_s.freeze
    end

    def launch_party_name
      FeatureConstants::EMBERIZE_BUSINESS_HOURS
    end
end
