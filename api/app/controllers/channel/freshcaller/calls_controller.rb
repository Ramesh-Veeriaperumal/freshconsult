class Channel::Freshcaller::CallsController < ApiApplicationController
  include ::Freshcaller::JwtAuthentication
  include ::Freshcaller::CallConcern
  skip_before_filter :check_privilege, :set_current_account, :check_day_pass_usage_with_user_time_zone
  before_filter :reset_current_user
  before_filter :custom_authenticate_request
  decorate_views(decorate_object: [:create])

  def create
    if @item.save!
      response.api_root_key = 'freshcaller_call'
      render_201_with_location(location_url: 'freshcaller_calls_url')
    else
      render_request_error :internal_error, 400
    end
  end

  def update
    call_delegator = CallDelegator.new(@item, @options.slice(:ticket_display_id, :agent_email, :contact_id))
    if call_delegator.valid?
      load_call_attributes call_delegator
      handle_call_status_flows
      @item.recording_status = params[:recording_status] if params[:recording_status].present?
      if @item.save
        response.api_root_key = 'freshcaller_call'
        render_201_with_location(location_url: 'freshcaller_calls_url')
      else
        render_custom_errors(@item)
      end
    else
      render_custom_errors(call_delegator, true)
    end
  end

  private

    def scoper
      current_account.freshcaller_calls
    end

    def handle_call_status_flows
      create_and_link_ticket if incoming_missed_call?
      create_ticket_add_note if voicemail? || completed? || outgoing_missed_call?
    end

    def create_and_link_ticket
      create_ticket
      @item.notable = @ticket
    end

    def create_ticket_add_note
      create_ticket if @ticket.blank?
      create_and_link_note
    end

    def create_ticket
      @ticket = current_account.tickets.build(ticket_params)
      @ticket.save!
    end

    def create_and_link_note
      note = @ticket.notes.build(note_params)
      note.save_note
      @item.notable = note
    end

    def load_object(*)
      if action_name == 'update'
        @item = scoper.where(fc_call_id: params[:id]).first
        log_and_render_404 unless @item
      end
    end

    def sanitize_params
      @options = params[cname].dup
      ParamsHelper.save_and_remove_params(self, ::Freshcaller::CallConstants::EXCLUDE_FIELDS, cname_params)
    end

    def validate_params
      field = "Freshcaller::CallConstants::#{action_name.upcase}_FIELDS".constantize
      params[cname].permit(*field)
      call_validation = ::Freshcaller::CallValidation.new(params[cname], @item, string_request_params?)
      valid = call_validation.valid?(action_name.to_sym)
      render_errors call_validation.errors, call_validation.error_options unless valid
    end

    def load_call_attributes(delegator)
      @ticket = delegator.ticket
      @agent = delegator.agent
      @contact = delegator.contact || load_contact_from_search || load_contact_from_number
    end

    def reset_current_user
      User.reset_current_user
    end
end
