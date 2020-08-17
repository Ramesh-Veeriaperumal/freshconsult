class Admin::ApiBusinessCalendarsController < ApiBusinessHoursController
  include BusinessCalendarBuilder
  include Admin::BusinessCalendarHelper

  decorate_views

  before_filter :business_calendar_validation, only: [:create, :update, :destroy]

  def index
    super
  end

  def show
    super
  end

  def create
    construct_default_params
    construct_business_hours_time_data
    construct_holiday_data
    @item.holiday_data = [] if @item.holiday_data.blank?
    if @item.save!
      render status: :created
    else
      render_custom_errors
    end
  end

  private

    def validate_params
      allowed_fields = "#{constants_class}::#{action_name.upcase}_FIELDS".constantize
      if params[cname].blank?
        custom_empty_param_error
      else
        params[cname].permit(*allowed_fields)
      end
    end

    def validation_class
      'Admin::BusinessCalendarsValidation'.constantize
    end

    def business_calendar_validation
      validator_klass = validation_class.new(params[cname], @item, {})
      errors = nil
      error_options = {}
      if validator_klass.invalid?(params[:action].to_sym)
        errors = validator_klass.errors
        error_options = validator_klass.error_options
      end
      render_errors(errors, error_options) if errors.present?
    end

    def decorator_options
      super({ groups: Account.current.groups_from_cache })
    end

    def constants_class
      'ApiBusinessCalendarConstants'.freeze
    end

    def launch_party_name
      FeatureConstants::EMBERIZE_BUSINESS_HOURS
    end
end
