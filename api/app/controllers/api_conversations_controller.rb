class ApiConversationsController < ApiApplicationController
  include TicketConcern
  include CloudFilesHelper
  include Conversations::Email
  include Concerns::ApplicationViewConcern
  include HelperConcern
  include ConversationConcern
  include AttachmentConcern

  decorate_views(
    decorate_object: %i(forward reply_to_forward)
  )

  before_filter :can_send_user?, only: [:forward, :reply_to_forward]
  before_filter :set_defaults, only: [:forward]

  SINGULAR_RESPONSE_FOR = %w(forward reply_to_forward).freeze

  def forward
    return unless validate_params
    sanitize_and_build
    return unless validate_delegator(@item, delegator_hash.merge(cloud_file_ids: @cloud_file_ids))
    save_note_and_respond
  end

  def reply_to_forward
    return unless validate_params
    sanitize_and_build
    return unless validate_delegator(@item, delegator_hash)
    save_note_and_respond
  end

  private

    def decorator_options(options = {})
      options[:ticket] = @ticket
      super(options)
    end

    def validate_params
      field = "ConversationConstants::#{action_name.upcase}_FIELDS".constantize
      params[cname].permit(*field)
      @conversation_validation = ConversationValidation.new(params[cname], @item, string_request_params?)
      valid = @conversation_validation.valid?(action_name.to_sym)
      render_errors @conversation_validation.errors, @conversation_validation.error_options unless valid
      valid
    end

    def set_defaults
      cname_params[:include_quoted_text] = true unless cname_params.key?(:include_quoted_text) || cname_params.key?(:full_text)
      cname_params[:include_original_attachments] = true unless cname_params.key?(:include_original_attachments)
    end

    def sanitize_and_build
      sanitize_params
      build_object
      kbase_email_included? cname_params # kbase_email_included? present in Email module
      assign_note_attributes
    end

    def sanitize_params
      sanitize_note_params
    end

    def assign_note_attributes
      # assign user instead of id as the object is already loaded.
      assign_user @item
      @item.to_emails = params[cname][:to_emails] if reply_to_forward?
      @item.notable = @ticket # assign notable instead of id as the object is already loaded.
      @item.notable.account = current_account
      load_normal_attachments
      build_normal_attachments(@item, cname_params[:attachments])
      build_shared_attachments(@item, shared_attachments)
      build_cloud_files(@item, @cloud_files)
      @item.attachments = @item.attachments # assign attachments so that it will not be queried again in model callbacks
      @item.inline_attachments = @item.inline_attachments
    end

    def assign_user(_item)
      if @item.user_id
        @item.user = @user if @user
      else
        @item.user = api_current_user
      end
    end

    def load_normal_attachments
      attachments_array = cname_params[:attachments] || []
      (parent_attachments || []).each do |attach|
        attachments_array.push(resource: attach.to_io)
      end
      cname_params[:attachments] = attachments_array
    end

    def delegator_hash
      { parent_attachments: parent_attachments, attachment_ids: @attachment_ids, shared_attachments: shared_attachments, inline_attachment_ids: @inline_attachment_ids }
    end

    def save_note_and_respond
      is_success = save_note
      # publish solution is being set in kbase_email_included based on privilege and email params
      if is_success
        create_solution_article if @create_solution_privilege
      end
      render_response(is_success)
    end

    def save_note
      assign_extras
      @item.save_note
    end

    def save_note_later
      assign_extras
      @item.save_note_later(@create_solution_privilege, false)
    end

    def assign_attributes_for_forward
      @item.private = true
      @item.build_note_body unless @item.note_body
      @item.note_body.full_text_html ||= (@item.note_body.body_html || '')
      @item.note_body.full_text_html = @item.note_body.full_text_html + bind_last_conv(@ticket, signature, true) if @include_quoted_text
      load_cloud_files
    end

    def load_cloud_files
      build_cloud_files(@item, parent_cloud_files || [])
    end

    def parent_attachments
      # query direct and shared attachments of associated ticket
      @parent_attachments ||= begin
        attachments = []
        if @include_original_attachments
          attachments = @ticket.all_attachments
        elsif @attachment_ids
          attachments = (@ticket.all_attachments | conversations_attachments | child_tickets_attachments).select { |x| @attachment_ids.include?(x.id) }
        end
        account_attachments = get_account_attachments(attachments)
        attachments.push(account_attachments).flatten
      end
    end

    def get_account_attachments attachments
      # Returns attachment objects for ids not from current ticket
      @account_attachments = []
      attachment_ids = (@attachment_ids || [])- attachments.flatten.map(&:id)
      @account_attachments.push(current_account.attachments.where(id: attachment_ids, attachable_type: "Helpdesk::Note"))
      @account_attachments.flatten!
    end

    def conversations_attachments
      @converation_attachments ||= begin
        @ticket.notes.visible.preload(:attachments).map(&:attachments).flatten
      end
    end

    def child_tickets_attachments
      @child_tickets_attachments ||= begin
        @ticket.assoc_parent_ticket? ? @ticket.associated_subsidiary_tickets('assoc_parent', [:attachments]).map(&:attachments).flatten : []
      end
    end

    def shared_attachments
      # shared attachments explicitly included in the  note
      @shared_attachments ||= begin
        attachments_to_exclude = forward? ? (parent_attachments || []).map(&:id) : []
        shared_attachment_ids = (@attachment_ids || []) - attachments_to_exclude
        return [] unless shared_attachment_ids.any?
        current_account.attachments.where('id IN (?) AND attachable_type IN (?)', shared_attachment_ids, AttachmentConstants::CLONEABLE_ATTACHMENT_TYPES)
      end
    end

    def parent_cloud_files
      if @include_original_attachments
        @ticket.cloud_files
      elsif @cloud_file_ids
        @delegator.cloud_file_attachments
      end
    end

    def signature
      (@user || api_current_user)
        .try(:agent)
        .try(:parsed_signature, 'ticket' => @ticket, 'helpdesk_name' => Account.current.portal_name)
    end

    def broadcast?
      @broadcast ||= current_action?('broadcast')
    end

    def reply_to_forward?
      @reply_to_forward ||= current_action?('reply_to_forward')
    end

    def forward?
      @forward ||= current_action?('forward')
    end

    def constants_class
      :ConversationConstants.to_s.freeze
    end

    def scoper
      current_account.notes
    end

    def load_parent_ticket # Needed here in controller to find the item by display_id
      @ticket = tickets_scoper.find_by_param(params[:id], current_account)
      log_and_render_404 unless @ticket
      @ticket
    end

    def tickets_scoper
      current_account.tickets
    end

    def assign_extras
      draft_attachments = @delegator.draft_attachments
      @item.attachments = @item.attachments + draft_attachments if draft_attachments
      @item.inline_attachment_ids = @inline_attachment_ids if @inline_attachment_ids
      assign_from_email
      assign_attributes_for_forward if forward?
    end

    def check_privilege
      return false unless super
      return false if ticket_required? && !load_parent_ticket
      verify_ticket_permission(api_current_user, @ticket) if @ticket
    end

    def ticket_required?
      ConversationConstants::TICKET_LOAD_REQUIRED.include?(action_name.to_sym)
    end

    def assign_from_email
      if @delegator.email_config
        @item.email_config_id = @delegator.email_config.id
        @item.from_email = current_account.personalized_email_replies_enabled? ? @delegator.email_config.friendly_email_personalize(current_user.name) : @delegator.email_config.friendly_email
      else
        @item.from_email = current_account.personalized_email_replies_enabled? ? @ticket.friendly_reply_email_personalize(current_user.name) : @ticket.selected_reply_email
      end
    end

    def render_response(success)
      if success
        render_201_with_location
      else
        render_custom_errors(@item)
      end
    end

    def create_solution_article
      body_html = @item.body_html
      title = @ticket.subject.length < 3 ? "Ticket:#{@ticket.display_id} subject is too short to be an article title" : @ticket.subject
      attachments = params[cname][:attachments]
      Helpdesk::KbaseArticles.create_article_from_note(current_account, @item.user, title, body_html, attachments)
    end
  
    def render_201_with_location(template_name: "conversations/#{action_name}", location_url: 'conversation_url', item_id: @item.id)
      return super(location_url: location_url)
    end

end
