class TicketSummaryController < ApiApplicationController
  include TicketConcern
  include CloudFilesHelper
  include HelperConcern
  include ConversationConcern
  include AttachmentConcern
  include Utils::Sanitizer
  decorate_views
  before_filter :can_send_user?, only: [:update]

  def update
    if create?
      build_object
    end
    assign_summary_attributes
    return unless validate_delegator(@item, delegator_hash)
    @item.inline_attachment_ids = @inline_attachment_ids
    @item.attachments = @item.attachments + @delegator.draft_attachments if @delegator.draft_attachments
    save_summary = @item.save_note
    render_custom_errors(@item) unless save_summary
  end

  def destroy
    @item.destroy
    head 204
  end

  def self.wrap_params
    TicketSummaryConstants::WRAP_PARAMS
  end

  private
    def decorator_options(options = {})
      options[:ticket] = @ticket
      super(options)
    end

    def assign_summary_attributes
      # assign user instead of id as the object is already loaded.
      assign_user unless @ticket.summary
      @item.notable = @ticket # assign notable instead of id as the object is already loaded.
      load_normal_attachments
      build_normal_attachments(@item, cname_params[:attachments])
      build_shared_attachments(@item, shared_attachments)
      # build_cloud_files(@item, @cloud_files)
      @item.attachments = @item.attachments # assign attachments so that it will not be queried again in model callbacks
      if @ticket.summary
        sanitize_body_text
        @item.assign_attributes(cname_params)
      end
    end

    def load_normal_attachments
      attachments_array = cname_params[:attachments] || []
      (parent_attachments || []).each do |attach|
        attachments_array.push(resource: attach.to_io)
      end
      cname_params[:attachments] = attachments_array
    end

    def parent_attachments
      @parent_attachments = []
      current_account.attachments.where(id: @attachment_ids).to_a.each do |attach|
      ticket_as_type = attach.attachable_type == AttachmentConstants::ATTACHABLE_TYPES["ticket"]
      conversation_as_type = attach.attachable_type == AttachmentConstants::ATTACHABLE_TYPES["conversation"]
        if ticket_as_type && attach.attachable_id == @ticket.id 
          @parent_attachments << attach
        elsif conversation_as_type && attach.attachable.notable_id == @ticket.id
          @parent_attachments << attach unless attach.attachable.deleted
        end
      end
      @parent_attachments
    end

    def shared_attachments
      # shared attachments explicitly included in the  note
      @shared_attachments ||= begin
        shared_attachment_ids = (@attachment_ids || [])
        return [] unless shared_attachment_ids.any?
        current_account.attachments.
                        where('id IN (?) AND attachable_type IN (?)',
                        shared_attachment_ids, AttachmentConstants::CLONEABLE_ATTACHMENT_TYPES)
      end
    end

    def assign_user
      if @item.user_id
        @item.user = @user if @user
      else
        @item.user = api_current_user
      end # assign user instead of id as the object is already loaded.
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields(TicketSummaryConstants::ERROR_FIELD_MAPPINGS, item)
    end

    def validate_params
      field = "TicketSummaryConstants::#{action_name.upcase}_FIELDS".constantize
      params[cname].permit(*field)
      ticket_summary_validation = TicketSummaryValidation.new(params[cname], @item, string_request_params?)
      valid = ticket_summary_validation.valid?(action_name.to_sym)
      render_errors ticket_summary_validation.errors, ticket_summary_validation.error_options unless valid
      valid
    end

    def sanitize_params
      sanitize_body_params
      params[cname].merge! ({
        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['summary'],
        :private => true,
        :notable_id => @ticket.id
      })
      modify_note_body_attributes
      update_edit_timestamps unless create?
      modify_attachment_params
      ParamsHelper.save_and_remove_params(self, TicketSummaryConstants::PARAMS_TO_SAVE_AND_REMOVE, cname_params)
      ParamsHelper.clean_params(TicketSummaryConstants::PARAMS_TO_REMOVE, cname_params)
      process_saved_params
    end

    def before_load_object
      unless Account.current.ticket_summary_enabled?
        render_request_error(:app_unavailable, 403, feature: 'Ticket summary', app: 'Summary') 
      end
      # load ticket and return 404 if ticket doesn't exists in case of APIs which has ticket_id in url
      return false unless load_parent_ticket
      if @ticket.spam_or_deleted? && !show?
        render_request_error(:access_denied, 403)
        return false
      end
      verify_ticket_permission(api_current_user, @ticket)
    end

    def load_object
      if @ticket.assoc_parent_ticket? || @ticket.tracker_ticket?
        render_request_error(:cant_access_summary, 403, feature: 'Ticket Summary', assoc_tkt: 'Parent and Tracker Tickets') 
      end
      return if update? && !@ticket.summary
      @item = @ticket.summary
      head 204 unless @item
    end

    def load_parent_ticket # Needed here in controller to find the item by display_id
      @ticket = tickets_scoper.find_by_param(params[:ticket_id], current_account)
      log_and_render_404 unless @ticket  #check for invalid ticket
      @ticket
    end

    def tickets_scoper
      current_account.tickets
    end

    def create?
      !@item && update? && !@ticket.summary
    end

    def sanitize_body_text
      @item.assign_element_html(cname_params[:note_body_attributes], 'body') if cname_params[:note_body_attributes]
      sanitize_body_hash(cname_params, :note_body_attributes, 'body') if cname_params
    end

    def constants_class
      :TicketSummaryConstants.to_s.freeze
    end

    def delegator_hash
      { parent_attachments: parent_attachments, attachment_ids: @attachment_ids, shared_attachments: shared_attachments, inline_attachment_ids: @inline_attachment_ids }
    end

    def scoper
      current_account.notes
    end

    def valid_content_type?
      return true if super
      allowed_content_types = TicketSummaryConstants::ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym] || [:json]
      allowed_content_types.include?(request.content_mime_type.ref)
    end
    # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
    wrap_parameters(*wrap_params)
end