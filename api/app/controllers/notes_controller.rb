class NotesController < ApiApplicationController
  wrap_parameters :note, exclude: [], format: [:json, :multipart_form]

  include Concerns::NoteConcern
  include CloudFilesHelper

  skip_before_filter :build_object
  before_filter :load_ticket, :can_send_user?, :build_object, only: [:create]

  def create
    @item.user_id ||= current_user.id
    build_normal_attachments(@item, params[cname][:attachments])
    if @item.save_note
      render '/notes/create', location: send("#{nscname}_url", @item.id), status: 201
    else
      render_error(@item.errors)
    end
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

    def can_update_note?
      unless @item.source == Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note']
        @error = BaseError.new(:method_not_allowed, methods: 'DELETE')
        render '/base_error', status: 405
        return false
      end
    end

    def load_ticket # Needed here in controller to find the item by display_id
      @ticket = Helpdesk::Ticket.find_by_param(params[cname][:notable_id], current_account)
      unless @ticket
        @errors = [BadRequestError.new('ticket_id', "can't be blank")]
        render '/bad_request_error', status: 400
      end
    end

    def scoper
      @ticket ? @ticket.notes : current_account.notes
    end

    def validate_params
      return false if @item && !can_update_note? && action_name == 'UPDATE'
      field = "ApiConstants::#{action_name.upcase}_NOTE_FIELDS".constantize
      params[cname].permit(*(field))
      note = NoteValidation.new(params[cname], @item)
      render_error note.errors unless note.valid?
    end

    def manipulate_params
      params[cname][:source] = Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'] unless @item
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
