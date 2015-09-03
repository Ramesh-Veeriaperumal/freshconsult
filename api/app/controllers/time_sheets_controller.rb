class TimeSheetsController < ApiApplicationController
  include Concerns::TimeSheetConcern

  before_filter :ticket_exists?, only: [:ticket_time_sheets]
  before_filter :validate_toggle_params, only: [:toggle_timer]

  def index
    load_objects(time_sheet_filter.includes(:workable))
  end

  def create
    # If any validation is introduced in the TimeSheet model,
    # update_running_timer and @time_sheet.save should be wrapped in a transaction.
    update_running_timer params[cname][:agent_id] if @timer_running
    @item.workable = @ticket
    super
  end

  def update
    user_stop_timer =  params[cname].key?(:agent_id) ? params[cname][:agent_id] : @item.user_id
    # Should stop timer if the timer is on or if different agent_id is set as part of update
    update_running_timer user_stop_timer if should_stop_running_timer?
    super
  end

  def toggle_timer
    timer_running = @item.timer_running
    changed = fetch_changed_attributes(timer_running)
    changed.merge!(timer_running: !timer_running)
    render_errors @item.errors unless @item.update_attributes(changed)
  end

  def ticket_time_sheets
    @items = paginate_items(scoper.where(workable_id: @id))
    render '/time_sheets/index'
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

    def ticket_exists?
      # Load only non deleted ticket.
      @display_id = params[:id].to_i
      @id = current_account.tickets.select(:id).where(display_id: @display_id, deleted: false, spam: false).limit(1).first
      head 404 unless @id
    end

    def load_ticket
      # Load only non deleted ticket.
      @ticket = current_account.tickets.where(display_id: params[:id].to_i, deleted: false, spam: false).first
      head 404 unless @ticket
      @ticket
    end

    def scoper
      current_account.time_sheets
    end

    def time_sheet_filter
      time_sheet_filter_params = params.slice(*TimeSheetConstants::INDEX_FIELDS)
      scoper.filter(time_sheet_filter_params)
    end

    def validate_filter_params
      params.permit(*TimeSheetConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      timesheet_filter = TimeSheetFilterValidation.new(params, nil)
      render_errors timesheet_filter.errors, timesheet_filter.error_options unless timesheet_filter.valid?
    end

    def validate_params
      return false if create? && !load_ticket
      @timer_running = update? ? handle_existing_timer_running : handle_default_timer_running
      fields = get_fields("TimeSheetConstants::#{action_name.upcase}_FIELDS")
      params[cname].permit(*fields)
      @time_sheet_val = TimeSheetValidation.new(params[cname], @item, @timer_running)
      render_errors @time_sheet_val.errors, @time_sheet_val.error_options unless @time_sheet_val.valid?(action_name.to_sym)
    end

    def validate_toggle_params
      params[cname].permit({})
    end

    def sanitize_params
      params[cname][:timer_running] = @timer_running
      params[cname][:time_spent] = time_spent
      params[cname][:agent_id] ||= api_current_user.id if create?
      current_time = Time.zone.now
      params[cname][:executed_at] ||= current_time if create?
      params[cname][:start_time] ||= current_time if create? || params[cname][:timer_running].to_s.to_bool
      ParamsHelper.assign_and_clean_params({ agent_id: :user_id },
                                           params[cname])
    end

    def time_spent
      time_spent = convert_duration(params[cname][:time_spent]) if create? || params[cname].key?(:time_spent)
      time_spent ||= total_running_time if update? && !params[cname][:timer_running].to_s.to_bool
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
      return true if params[cname][:timer_running].to_s.to_bool && !@item.timer_running

      # Should stop timer for the new user if different agent_id is set as part of this update call
      return true if params[cname].key?(:agent_id) && params[cname][:agent_id] != @item.user_id && !@timer_running
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
