class TimeSheetsController < ApiApplicationController
  include TimeSheetConcern

  before_filter :load_object, except: [:create, :index, :route_not_found]
  before_filter :check_params, only: :update
  before_filter :validate_params, only: [:create, :update]
  before_filter :validate_filter_params, only: [:index]
  before_filter :validate_toggle_params, only: [:toggle_timer]
  before_filter :manipulate_params, only: [:create, :update]
  before_filter :build_object, only: [:create]
  before_filter :load_objects, only: [:index]


  def index
    load_objects(time_sheet_filter.includes(:workable))
  end

  def create
    # If any validation is introduced in the TimeSheet model,
    # update_running_timer and @time_sheet.save should be wrapped in a transaction.
    update_running_timer params[cname][:user_id] if @timer_running
    @item.workable = @time_sheet_val.ticket
    super
  end

  def update
    user_stop_timer =  params[cname].key?(:user_id) ? params[cname][:user_id] : @item.user_id
    # Should stop timer if the timer is on or if different user_id is set as part of update
    update_running_timer user_stop_timer if should_stop_running_timer?
    super
  end

  def toggle_timer
    timer_running = @item.timer_running
    changed = fetch_changed_attributes(timer_running)
    changed.merge!(timer_running: !timer_running)
    unless @item.update_attributes(changed)
      render_error @item.errors
    end
  end

  private

    def fetch_changed_attributes(timer_running)
      if timer_running
        { time_spent: calculate_time_spent(@item) }
      else
        # If any validation is introduced in the TimeSheet model,
        # update_running_timer and @item.update_attributes should be wrapped in a transaction.
        update_running_timer @item.user_id
        { start_time: Time.zone.now }
      end
    end

    def feature_name
      FeatureConstants::TIMESHEET
    end

    def scoper
      current_account.time_sheets
    end

    def time_sheet_filter
      time_sheet_filter_params = params.slice(*TimeSheetConstants::INDEX_TIMESHEET_FIELDS)
      scoper.filter(time_sheet_filter_params)
    end

    def validate_filter_params
      params.permit(*TimeSheetConstants::INDEX_TIMESHEET_FIELDS, *ApiConstants::DEFAULT_PARAMS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      timesheet_filter = TimeSheetFilterValidation.new(params, nil)
      render_error timesheet_filter.errors, timesheet_filter.error_options unless timesheet_filter.valid?
    end

    def validate_params
      @timer_running = update? ? handle_existing_timer_running : handle_default_timer_running
      fields = get_fields("TimeSheetConstants::#{action_name.upcase}_TIME_SHEET_FIELDS")
      params[cname].permit(*fields)
      @time_sheet_val = TimeSheetValidation.new(params[cname], @item, @timer_running)
      render_error @time_sheet_val.errors, @time_sheet_val.error_options unless @time_sheet_val.valid?(action_name.to_sym)
    end

    def validate_toggle_params
      params[cname].permit({})
    end

    def manipulate_params
      params[cname][:timer_running] = @timer_running
      params[cname][:time_spent] = time_spent
      params[cname][:user_id] ||= current_user.id if create?
      current_time = Time.zone.now
      params[cname][:executed_at] ||= current_time if create?
      params[cname][:start_time] ||= current_time if create? || params[cname][:timer_running].to_s.to_bool == true
      params[cname].delete(:ticket_id)
    end

    def time_spent
      time_spent = convert_duration(params[cname][:time_spent]) if create? || params[cname].key?(:time_spent)
      time_spent ||= total_running_time if update? && params[cname][:timer_running].to_s.to_bool == false
      time_spent
    end

    def handle_existing_timer_running
      # Needed in validation to validate start_time based on timer_running attribute in update action.
      timer_running = params[cname].key?(:timer_running) ? params[cname][:timer_running] : @item.timer_running
      timer_running
    end

    def handle_default_timer_running
      # Needed in validation to validate start_time based on timer_running attribute in create action.
      timer_running = params[cname][:timer_running]
      unless params[cname].key?(:timer_running)
        timer_running ||= !params[cname].key?(:time_spent) || params[cname].key?(:start_time)
      end
      timer_running
    end

    def should_stop_running_timer?
      # Should stop timer if the timer is on as part of this update call
      return true if params[cname][:timer_running].to_s.to_bool == true && @item.timer_running.to_s.to_bool == false

      # Should stop timer for the new user if different user_id is set as part of this update call
      return true if params[cname].key?(:user_id) && params[cname][:user_id] != @item.user_id && @timer_running.to_s.to_bool == false
      false
    end

    def total_running_time
      @item.time_spent.to_i + (Time.now - @item.start_time).abs.round
    end

    def convert_duration(time_spent)
      # Convert hh:mm string to seconds. Say 00:02 string to 120 seconds.
      time = time_spent.to_s.split(':').map.with_index { |x, i| x.to_i.send(ApiConstants::TIME_UNITS[i]) }.reduce(:+).to_i
      time
    end
end
