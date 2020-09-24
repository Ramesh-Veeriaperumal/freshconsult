class Channel::Freshcaller::CallsController < ApiApplicationController
  include ::Freshcaller::JwtAuthentication
  include ::Freshcaller::CallConcern
  skip_before_filter :check_privilege, :check_day_pass_usage_with_user_time_zone
  before_filter :reset_current_user
  before_filter :filter_current_user, only: [:create, :update]
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
    call_delegator = CallDelegator.new(@item, @options.slice(:ticket_display_id, :agent_email, :call_agent_email, :contact_id))
    if call_delegator.valid?
      load_call_attributes call_delegator
      Account.current.launched?(:freshcaller_ticket_revamp) ? add_call_info : handle_call_status_flows # We can remove this in auto ticket creation check PR
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

    def filter_current_user
      @load_current_user = true
    end

    def scoper
      current_account.freshcaller_calls
    end

    def handle_call_status_flows
      create_or_update_ticket if (incoming_missed_call? || abandoned?) && !callback_parent?
      create_or_add_to_ticket if ongoing?
      create_ticket_add_note if (voicemail? || completed? || outgoing_missed_call?) && !callback_parent?
    end

    def add_call_info
      if params[:call_status].present?
        @item.call_info = call_info
        return if @ticket.blank?
        return create_and_link_note unless update_existing_note?

        update_note_body
      end
    end

    def create_or_update_ticket
      return update_ticket_details if @ticket.present? && abandoned?
      create_and_link_ticket
    end

    def create_and_link_ticket
      create_ticket
      @item.notable = @ticket
      create_and_link_note if call_notes?
    end

    def create_or_add_to_ticket
      return create_and_link_ticket if @ticket.blank?
      create_and_link_note
    end

    def create_ticket_add_note
      create_ticket if @ticket.blank?
      return create_and_link_note unless update_existing_note?
      update_note_body
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

    def update_ticket_details
      @ticket.update_ticket_attributes(update_ticket_params)
      update_note_body if update_existing_note?
    end

    def update_note_body
      ticket_note.last.update_note_attributes(note_body_attributes:
        { body_html: "#{description} #{duration} #{call_notes}" })
    end

    def load_object(*)
      @item = build_object if action_name == 'update'
    end

    def build_object
      # TODO: We can remove after deployment 03.08.18
      fc_call_id = params[:id] || params[:fc_call_id]
      log_and_render_404 if fc_call_id.blank?
      @item = scoper.where(fc_call_id: fc_call_id).first_or_initialize
      @item.account = current_account
      @item
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
      @ticket = delegator.ticket || @item.associated_ticket
      @agent = delegator.agent unless non_attended_call?
      @contact = delegator.contact || load_contact_from_search || load_contact_from_number
      resolve_creator delegator
      resolve_call_agent delegator
    end

    def resolve_creator(delegator)
      return @creator = delegator.creator unless non_attended_call?

      reset_current_user
    end

    def resolve_call_agent(delegator)
      @call_agent = delegator.call_agent unless non_attended_call?
    end

    def reset_current_user
      User.reset_current_user
    end

    def ticket_note
      @ticket.notes.conversations.where(id: @item.notable_id)
    end

    def update_existing_note?
      @ticket.notes.conversations.present? && ticket_note.present?
    end
end
