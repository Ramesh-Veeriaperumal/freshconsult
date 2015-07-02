class TimeSheetsController < ApiApplicationController
  include TimeSheetConcern

  before_filter :validate_filter_params, only: [:index]
  before_filter :build_object, only: [:create]

  def index
    load_objects(time_sheet_filter.includes(:workable))
  end

  def create
    # If any validation is introduced in the TimeSheet model, 
    # update_running_timer and @item.save should be wrapped in a transaction.
    update_running_timer params[cname][:user_id] if @timer_running
    @item.workable = @time_sheet_val.ticket
    super
  end

  def update
  end

  def toggle_timer
  end

  private

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
      fields = get_fields("TimeSheetConstants::#{action_name.upcase}_TIME_SHEET_FIELDS")
      params[cname].permit(*fields)
      @time_sheet_val = TimeSheetValidation.new(params[cname], @item, current_account, @timer_running)
      render_error @time_sheet_val.errors unless @time_sheet_val.valid?
    end

    def manipulate_params
      params[cname].reverse_merge!({
        :timer_running => @timer_running,
        :time_spent => convert_duration(params[cname][:time_spent]),
        :executed_at => Time.zone.now,
        :start_time => Time.zone.now,
      }).delete(:ticket_id)
    end

    def handle_default_timer_running
      @timer_running = params[cname][:timer_running] 
      unless params[cname].key?(:timer_running)
        @timer_running ||= !params[cname].key?(:time_spent) || params[cname].key?(:start_time)
      end
    end
end
