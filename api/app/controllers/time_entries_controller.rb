class TimeEntriesController < ApiApplicationController
  include TicketConcern

  def create
    # If any validation is introduced in the TimeSheet model,
    # update_running_timer and @item.save should be wrapped in a transaction.
    update_running_timer params[cname][:user_id] if @timer_running
    super
  end

  def update
    user_stop_timer =  params[cname].key?(:user_id) ? params[cname][:user_id] : @item.user_id
    # Should stop other timers for the above user_stop_timer
    # if the timer is on for this time_entry in this update call
    # or this user_stop_timer is newly assigned to this time_entry in this update call
    update_running_timer user_stop_timer if should_stop_running_timer?
    super
  end

  def toggle_timer
    timer_running = @item.timer_running
    changed = fetch_changed_attributes(timer_running)
    changed.merge!(timer_running: !timer_running)
    render_errors @item.errors unless @item.update_attributes(changed)
  end

  def ticket_time_entries
    return if validate_filter_params
    @items = paginate_items(scoper.where(workable_id: @ticket.id))
    render '/time_entries/index'
  end

  private

    def after_load_object
      return false unless load_workable_from_item # find ticket in case of APIs which has @item.id in url

      # Verify ticket permission if ticket exists.
      return false if @ticket && !verify_ticket_permission(api_current_user, @ticket)

      # Ensure that no parameters are passed along with the toggle_timer request
      if action_name == 'toggle_timer' && params[cname].present?
        render_request_error :no_content_required, 400
      end
    end

    def load_objects
      super time_entry_filter.preload(:workable)
    end

    def fetch_changed_attributes(timer_running)
      if timer_running
        { time_spent: @item.calculate_time_spent }
      else
        # If any validation is introduced in the TimeSheet model,
        # update_running_timer and @item.update_attributes should be wrapped in a transaction.
        update_running_timer @item.user_id
        { start_time: Time.zone.now }
      end
    end

    def feature_name
      FeatureConstants::TIME_ENTRIES
    end

    def load_parent_ticket
      # Load only non deleted ticket.
      @ticket = current_account.tickets.where(display_id: params[:id], deleted: false, spam: false).first
      head 404 unless @ticket
      @ticket
    end

    def load_workable_from_item
      @ticket = @item.workable
      spam_or_deleted_ticket = @ticket.deleted || @ticket.spam
      if spam_or_deleted_ticket
        Rails.logger.error "Can't load spam/deleted ticket. Params: #{params.inspect} Id: #{params[:id]} Ticket display_id: #{@ticket.try(:display_id)} spam_or_deleted_ticket: #{spam_or_deleted_ticket}}"
        head 404
      end
      !spam_or_deleted_ticket
    end

    def scoper
      current_account.time_sheets
    end

    def time_entry_filter
      time_entry_filter_params = params.slice(*TimeEntryConstants::INDEX_FIELDS)
      scoper.filter(time_entry_filter_params)
    end

    def validate_filter_params
      params.permit(*TimeEntryConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      timeentry_filter = TimeEntryFilterValidation.new(params, nil, string_request_params?)
      render_query_param_errors timeentry_filter.errors, timeentry_filter.error_options unless timeentry_filter.valid?
    end

    def validate_params
      @timer_running = update? ? handle_existing_timer_running : handle_default_timer_running
      fields = get_fields("TimeEntryConstants::#{action_name.upcase}_FIELDS")
      params[cname].permit(*fields)
      @time_entry_val = TimeEntryValidation.new(params[cname], @item, @timer_running)
      render_errors @time_entry_val.errors, @time_entry_val.error_options unless @time_entry_val.valid?(action_name.to_sym)
    end

    def sanitize_params
      current_time = Time.zone.now
      if create?
        params[cname][:timer_running] = @timer_running
        params[cname][:agent_id] ||= api_current_user.id
      end
      params[cname][:executed_at] ||= get_executed_at(current_time)
      params[cname][:start_time] ||= get_start_time(current_time)
      set_time_spent(params)
      ParamsHelper.assign_and_clean_params({ agent_id: :user_id },
                                           params[cname])
    end

    def assign_protected
      @item.workable = @ticket
    end

    def get_executed_at(current_time)
      create? ? current_time : @item.executed_at
    end

    def get_start_time(current_time)
      (create? || params[cname][:timer_running]) ? current_time : @item.start_time
    end

    def set_time_spent(params)
      params[cname][:time_spent] = convert_duration(params[cname][:time_spent]) if create? || params[cname].key?(:time_spent)
      params[cname][:time_spent] ||= @item.calculate_time_spent if update? && params[cname][:timer_running] == false
    end

    def handle_existing_timer_running
      # Needed in validation to validate start_time based on timer_running attribute in update action.
      params[cname].key?(:timer_running) ? params[cname][:timer_running] : @item.timer_running
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
      return true if params[cname][:timer_running] && !@item.timer_running
    end

    def convert_duration(time_spent)
      # Convert hh:mm string to seconds. Say 00:02 string to 120 seconds.
      # Preferring naive conversion because of performance.
      time_split = time_spent.to_s.split(':')
      (time_split.first.to_i.hours + time_split.last.to_i.minutes).to_i
    end

    def check_privilege
      return false unless super # break if there is no enough privilege.

      # load ticket and return 404 if ticket doesn't exists in case of APIs which has ticket_id in url
      return false if (create? || ticket_time_entries?) && !load_parent_ticket
      verify_ticket_permission(api_current_user, @ticket) if @ticket
    end

    def ticket_time_entries?
      @ticket_notes ||= current_action?('ticket_time_entries')
    end

    def update_running_timer(user_id)
      @time_cleared = current_account.time_sheets.where(user_id: user_id, timer_running: true)
      @time_cleared.each { |tc| tc.update_attributes(timer_running: false, time_spent: tc.calculate_time_spent) }
    end
end
