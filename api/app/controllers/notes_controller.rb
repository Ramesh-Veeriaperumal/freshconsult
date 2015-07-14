class NotesController < ApiApplicationController
  wrap_parameters :note, exclude: [], format: [:json, :multipart_form]

  include Concerns::NoteConcern
  include CloudFilesHelper
  include Conversations::Email

  before_filter :load_object, :check_agent_note, only: [:update, :destroy]
  before_filter :can_update?, only: [:update]
  before_filter :load_ticket, only: [:reply]
  before_filter :validate_params, :manipulate_params, only: [:update, :create, :reply]
  before_filter :can_send_user?, :build_object, only: [:create, :reply]
  before_filter -> { kbase_email_included? params[cname] }, only: [:reply] # kbase_email_included? present in Email module

  def create
    is_success = create_note
    render_response(is_success)
  end

  def reply
    is_success = create_note
    render_response(is_success)
    # publish solution is being set in kbase_email_included based on privilege and email params
    create_solution_article if is_success && @publish_solution
  end

  def update
    build_normal_attachments(@note, params[cname][:attachments])
    unless @note.update_note_attributes(params[cname])
      render_error(@note.errors)
    end
  end

  def destroy
    @note.update_attribute(:deleted, true)
    head 204
  end

  private

    def create_solution_article
      body_html = @note.body_html
      # title is set only for API if the ticket subject length is lesser than 3. from UI, it fails silently.
      title = @ticket.subject.length < 3 ? "Ticket:#{@ticket.display_id} subject is too short to be an article title" : @ticket.subject
      attachments = params[cname][:attachments]
      Helpdesk::KbaseArticles.create_article_from_note(current_account, @note.user, title, body_html, attachments)
    end

    def create_note
      @note.user ||= current_user if @note.user_id.blank? # assign user instead of id as the object is already loaded.
      @note.notable = @ticket # assign notable instead of id as the object is already loaded.
      @note.notable.account = current_account
      attachments = build_normal_attachments(@note, params[cname][:attachments])
      @note.attachments =  attachments.present? ? attachments : [] # assign attachments so that it will not be queried again in model callbacks
      @note.save_note
    end

    def render_response(success)
      if success
        render "/notes/#{action_name}", location: send("#{nscname}_url", @note.id), status: 201
      else
        ErrorHelper.rename_error_fields({ notable_id: :ticket_id, user: :user_id }, @note)
        render_error(@note.errors)
      end
    end

    def can_update?
      # note without source type as 'note' should not be allowed to update
      unless @note.source == Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note']
        @error = BaseError.new(:method_not_allowed, methods: 'DELETE')
        render '/base_error', status: 405
      end
    end

    def load_ticket # Needed here in controller to find the item by display_id
      @ticket = current_account.tickets.find_by_param(params[:ticket_id], current_account)
      head 404 unless @ticket
    end

    def scoper
      current_account.notes
    end

    def validate_params
      field = "NoteConstants::#{action_name.upcase}_NOTE_FIELDS".constantize
      params[cname].permit(*(field))
      @note_validation = NoteValidation.new(params[cname], @note, can_validate_ticket)
      render_error @note_validation.errors, @note_validation.error_options unless @note_validation.valid?
    end

    def manipulate_params
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
      render_request_error(:access_denied, 403) if @note.user && @note.user.customer?
    end

    def load_object
      item = scoper.visible.find_by_id(params[:id])
      @item = instance_variable_set('@' + cname, item)
      head :not_found unless @note
    end

    def can_validate_ticket
      create?
    end
end
