class Admin::ApiBusinessCalendarsController < ApiBusinessHoursController
  include BusinessCalendarBuilder
  include Admin::BusinessCalendarHelper

  decorate_views

  before_filter :business_calendar_validation, only: [:create, :update, :destroy]

  def load_object(items = scoper)
    @item = items.find_by_id(params[:id])
    log_and_render_404 unless @item
    if @item && show? && Account.current.omni_business_calendar?
      @item.fetch_omni_business_calendar
      render_request_error(:fetch_omni_business_calendar, 503) if @item.errors.present?
    end
  end

  def index
    super
    response.api_meta = { count: @items_count }
  end

  def show
    super
  end

  def create
    construct_default_params
    construct_business_hours_time_data
    construct_holiday_data
    @item.holiday_data = [] if @item.holiday_data.blank?
    assign_channel_bc_api_params
    if @item.save!
      render status: Account.current.omni_business_calendar? ? 202 : 201
    else
      render_custom_errors
    end
  end

  def update
    construct_default_params
    construct_business_hours_time_data
    construct_holiday_data
    assign_channel_bc_api_params
    if @item.save!
      render status: Account.current.omni_business_calendar? ? 202 : 200
    else
      render_custom_errors
    end
  end

  def destroy
    @item.destroy
    head 204
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
      validator_klass = validation_class.new((params[cname] || {}), @item, {})
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
