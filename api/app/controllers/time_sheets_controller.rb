class TimeSheetsController < ApiApplicationController
  include TimeSheetConcern

  before_filter :validate_filter_params, only: [:index]
  before_filter :build_object, only: [:create]
  before_filter :check_permission, only: [:create, :toggle_timer]
  before_filter :validate_toggle_params, only: [:toggle_timer]

  def index
    load_objects(time_sheet_filter.includes(:workable))
  end

  def create
    # If any validation is introduced in the TimeSheet model, 
    # update_running_timer and @item.save should be wrapped in a transaction.
    update_running_timer params[cname][:user_id] if @timer_running
    @item.workable = @time_sheet_val.ticket
    @time_spent = view_duration(@time_sheet.time_spent)
    super
  end

  def update
  end

  def toggle_timer
    timer_running = @time_sheet.timer_running
    changed = if timer_running
      {time_spent: calculate_time_spent(@time_sheet)}
    else
      # If any validation is introduced in the TimeSheet model, 
      # update_running_timer and @item.update_attributes should be wrapped in a transaction.
      update_running_timer @time_sheet.user_id
      {start_time: Time.zone.now }
    end
    changed.merge!({:timer_running => !timer_running})
    if @time_sheet.update_attributes(changed)
      @time_spent = view_duration(@time_sheet.time_spent)
    else
      render_error @time_sheet.errors
    end
  end

  private

    def check_permission
      unless @time_sheet.user_id == current_user.id || privilege?(:edit_time_entries)
        access_denied && return
      end
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
      render_error timesheet_filter.errors unless timesheet_filter.valid?
    end

    def validate_params
      handle_default_timer_running
      fields = "TimeSheetConstants::#{action_name.upcase}_TIME_SHEET_FIELDS".constantize
      params[cname].permit(*fields)
      @time_sheet_val = TimeSheetValidation.new(params[cname], @item, current_account, @timer_running)
      render_error @time_sheet_val.errors unless @time_sheet_val.valid?
    end

    def validate_toggle_params
      params[cname].permit({})
    end

    def manipulate_params
      params[cname].merge!({
        :timer_running => @timer_running,
        :time_spent => convert_duration(params[cname][:time_spent])}
        ).reverse_merge!({
        :executed_at => Time.zone.now,
        :start_time => Time.zone.now,
        :user_id => current_user.id
      }).delete(:ticket_id)
    end

    def handle_default_timer_running
      @timer_running = params[cname][:timer_running] 
      unless params[cname].key?(:timer_running)
        @timer_running ||= !params[cname].key?(:time_spent) || params[cname].key?(:start_time)
      end
    end

    def view_duration(time)
      if time.is_a? Numeric
        time = (time.to_f/3600)
        hours = sprintf("%0.02d", time)
        minutes = sprintf("%0.02d", (time.modulo(1) * 60))
        "#{hours}:#{minutes}"
      end
    end
end
