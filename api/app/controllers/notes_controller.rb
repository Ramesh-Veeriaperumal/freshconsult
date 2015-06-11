class NotesController < ApiApplicationController
  wrap_parameters :note, exclude: [], format: [:json, :multipart_form]

  include Concerns::NoteConcern
  include CloudFilesHelper
  include Conversations::Email

  before_filter :load_object, only: [:update, :destroy]
  before_filter :validate_params, :manipulate_params, only: [:reply, :create, :update]
  before_filter :load_ticket, :can_send_user?, :build_object, only: [:create, :reply]
  before_filter -> { kbase_email_included? params[cname] }, only: [:reply]

  def create
    create_note
  end

  def reply
    # publish solution is being set in kbase_email_included based on privilege and email params
    create_solution_article if create_note && @publish_solution 
  end

  def update
    build_normal_attachments(@item, params[cname][:attachments])
    unless @item.update_note_attributes(params[cname])
      render_error(@item.errors)
    end
  end

  def destroy
    @item.update_attribute(:deleted, true)
    head 204
  end

  private

    def create_solution_article
      body_html = @item.body_html
      # title is set only for API if the ticket subject length is lesser than 3. from UI, it fails silently.
      title = @ticket.subject.length < 3 ? "Ticket:#{@ticket.display_id} subject is too short to be an article title" : @ticket.subject
      attachments = params[cname][:attachments]
      Helpdesk::KbaseArticles.create_article_from_note(current_account, current_user, title, body_html, attachments)
    end

    def create_note
      @item.user_id ||= current_user.id
      build_normal_attachments(@item, params[cname][:attachments])
      if @item.save_note
        render "/notes/#{action_name}", location: send("#{nscname}_url", @item.id), status: 201
        return true
      else
        render_error(@item.errors)
        return false
      end
    end

    def can_update_note?
      unless @item.source == Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note']
        @error = BaseError.new(:method_not_allowed, methods: 'DELETE')
        render '/base_error', status: 405
        return false
      end
      true
    end

    def load_ticket # Needed here in controller to find the item by display_id
      @ticket = Helpdesk::Ticket.find_by_param(params[cname][:notable_id], current_account)
      unless @ticket
        head(404) && return if "#{action_name.upcase}" == 'REPLY' # render 404 if reply action is called else 400
        @errors = [BadRequestError.new('ticket_id', "can't be blank")]
        render '/bad_request_error', status: 400
      end
    end

    def scoper
      @ticket ? @ticket.notes : current_account.notes
    end

    def validate_params
      return false if @item && !can_update_note? # dont update note if it is of type email (i.e., reply)
      params[cname][:ticket_id] = params[:ticket_id] if params[:ticket_id] # manually wrap params if it part of url
      field = "ApiConstants::#{action_name.upcase}_NOTE_FIELDS".constantize
      params[cname].permit(*(field))
      note = NoteValidation.new(params[cname], @item)
      render_error note.errors unless note.valid?
    end

    def manipulate_params
      params[cname][:source] = ApiConstants::NOTE_TYPE_FOR_ACTION[action_name] unless @item
      # only note can have choices for private field. 
      params[cname][:private] = false unless params[cname][:source] == Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note']
      assign_and_clean_params(notify_emails: :to_emails, ticket_id: :notable_id)
      build_note_body_attributes
      params[cname][:attachments] = params[cname][:attachments].map { |att| { resource: att } } if params[cname][:attachments]
    end

    def load_object
      condition = 'id = ? '
      condition += "and deleted = #{ApiConstants::DELETED_SCOPE[action_name]}" if ApiConstants::DELETED_SCOPE.keys.include?(action_name)
      item = scoper.where(condition, params[:id]).first
      @item = instance_variable_set('@' + cname, item)
      head :not_found unless @item
    end
end
