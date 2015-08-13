class NotesController < ApiApplicationController
  wrap_parameters :note, exclude: [], format: [:json, :multipart_form]

  include Concerns::NoteConcern
  include CloudFilesHelper
  include Conversations::Email

  before_filter :can_send_user?, only: [:create, :reply]
  before_filter :load_ticket, only: [:reply]
  before_filter :ticket_exists?, only: [:ticket_notes]

  def create
    is_success = create_note
    render_response(is_success)
  end

  def reply
    return unless validate_params
    sanitize_params
    build_object
    kbase_email_included? params[cname] # kbase_email_included? present in Email module
    is_success = create_note
    render_response(is_success)
    # publish solution is being set in kbase_email_included based on privilege and email params
    create_solution_article if is_success && @publish_solution
  end

  def update
    build_normal_attachments(@item, params[cname][:attachments]) if params[cname][:attachments]
    @item.assign_element_html(params[cname][:note_body_attributes], "body", "full_text") if params[cname][:note_body_attributes]
    unless @item.update_note_attributes(params[cname])
      render_custom_errors(@item)
    end
  end

  def destroy
    @item.update_attribute(:deleted, true)
    head 204
  end

  def ticket_notes
    notes = scoper.visible.exclude_source('meta').where(notable_id: @id).includes(:schema_less_note, :note_old_body, :attachments)
    @notes = paginate_items(notes)
  end

  private

    def after_load_object
      check_agent_note if update? || destroy?
      can_update? if update?
    end

    def create_solution_article
      body_html = @item.body_html
      # title is set only for API if the ticket subject length is lesser than 3. from UI, it fails silently.
      title = @ticket.subject.length < 3 ? "Ticket:#{@ticket.display_id} subject is too short to be an article title" : @ticket.subject
      attachments = params[cname][:attachments]
      Helpdesk::KbaseArticles.create_article_from_note(current_account, @item.user, title, body_html, attachments)
    end

    def create_note
      if @item.user_id
        @item.user = @user if @user
      else
        @item.user = current_user
      end # assign user instead of id as the object is already loaded.
      @item.notable = @ticket # assign notable instead of id as the object is already loaded.
      @item.notable.account = current_account
      attachments = build_normal_attachments(@item, params[cname][:attachments]) if params[cname][:attachments]
      @item.attachments = @item.attachments # assign attachments so that it will not be queried again in model callbacks
      @item.save_note
    end

    def render_response(success)
      if success
        render_201_with_location
      else
        render_custom_errors(@item)
      end
    end

    def set_custom_errors(item=@item)
      ErrorHelper.rename_error_fields({ notable_id: :ticket_id, user: :user_id }, item)
    end

    def can_update?
      # note without source type as 'note' should not be allowed to update
      unless @item.source == Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note']
        @error = BaseError.new(:method_not_allowed, methods: 'DELETE')
        render '/base_error', status: 405
      end
    end

    def load_ticket # Needed here in controller to find the item by display_id
      @ticket = current_account.tickets.find_by_param(params[:id], current_account)
      head 404 unless @ticket
    end

    def ticket_exists?
      @display_id = params[:id].to_i
      @id = current_account.tickets.where(display_id: @display_id).limit(1).select(:id).first
      head 404 unless @id
    end

    def load_object
      super scoper.visible
    end

    def scoper
      current_account.notes
    end

    def validate_params
      field = "NoteConstants::#{action_name.upcase}_NOTE_FIELDS".constantize
      params[cname].permit(*(field))
      @note_validation = NoteValidation.new(params[cname], @item, can_validate_ticket)
      valid = @note_validation.valid?
      render_errors @note_validation.errors, @note_validation.error_options unless valid
      valid
    end

    def sanitize_params
      # set source only for create/reply action not for update action. Hence NOTE_TYPE_FOR_ACTION is checked.
      params[cname][:source] = NoteConstants::NOTE_TYPE_FOR_ACTION[action_name] if NoteConstants::NOTE_TYPE_FOR_ACTION.keys.include?(action_name)

      # only note can have choices for private field. others will be set to false always.
      params[cname][:private] = false unless params[cname][:source] == Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note']

      # Set ticket id from already assigned ticket only for create/reply action not for update action.
      @ticket ||= @note_validation.ticket
      params[cname][:ticket_id] = @ticket.id if @ticket

      ParamsHelper.assign_and_clean_params({ notify_emails: :to_emails, ticket_id: :notable_id }, params[cname])
      build_note_body_attributes
      params[cname][:attachments] = params[cname][:attachments].map { |att| { resource: att } } if params[cname][:attachments]
    end

    def check_agent_note
      render_request_error(:access_denied, 403) if @item.user && @item.user.customer?
    end

    def can_validate_ticket
      create?
    end
end
