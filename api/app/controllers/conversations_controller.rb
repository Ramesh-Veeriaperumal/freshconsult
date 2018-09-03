class ConversationsController < ApiApplicationController
  include TicketConcern
  include CloudFilesHelper
  include Conversations::Email
  decorate_views(decorate_objects: [:ticket_conversations], decorate_object: [:create, :update, :reply])

  before_filter :can_send_user?, only: [:create, :reply]
  before_filter :check_for_broadcast, only: [:destroy, :update]

  COLLECTION_RESPONSE_FOR = ['ticket_conversations'].freeze

  SLAVE_ACTIONS = %w(ticket_conversations).freeze

  def create
    conversation_delegator = ConversationDelegator.new(@item, notable: @ticket)
    if conversation_delegator.valid?
      is_success = create_note
      render_response(is_success)
    else
      render_custom_errors(conversation_delegator, true)
    end
  end

  def reply
    remove_ignore_params unless private_api?
    return unless validate_params
    sanitize_params
    build_object
    kbase_email_included? params[cname] # kbase_email_included? present in Email module
    conversation_delegator = ConversationDelegator.new(@item, notable: @ticket)
    if conversation_delegator.valid?
      @item.email_config_id = conversation_delegator.email_config_id
      is_success = create_note
      # publish solution is being set in kbase_email_included based on privilege and email params
      create_solution_article if is_success && @publish_solution
      render_response(is_success)
    else
      render_custom_errors(conversation_delegator, true)
    end
  end

  def update
    @item.notable = @ticket # assign notable instead of id as the object is already loaded.
    build_normal_attachments(@item, params[cname][:attachments]) if params[cname][:attachments]
    @item.assign_element_html(params[cname][:note_body_attributes], 'body') if params[cname][:note_body_attributes]
    unless @item.update_note_attributes(params[cname])
      render_custom_errors(@item) # not_tested
    end
  end

  def destroy
    @item.update_attribute(:deleted, true)
    head 204
  end

  def ticket_conversations
    return if validate_filter_params
    preload_options = [:schema_less_note, :note_old_body, :attachments]
    ticket_conversations = @ticket.notes.conversations(preload_options, :created_at)
    @items = paginate_items(ticket_conversations)
  end

  def self.wrap_params
    ConversationConstants::WRAP_PARAMS
  end

  private

    def decorator_options(options = {})
      options[:ticket] = @ticket
      super(options)
    end

    def after_load_object
      load_notable_from_item # find ticket in case of APIs which has @item.id in url
      return false if @ticket && !verify_ticket_permission(api_current_user, @ticket) # Verify ticket permission if ticket exists.
      return false if update? && !can_update?
      check_agent_note if update? || destroy?
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
        @item.user = api_current_user
      end # assign user instead of id as the object is already loaded.
      @item.notable = @ticket # assign notable instead of id as the object is already loaded.
      @item.notable.account = current_account
      build_normal_attachments(@item, params[cname][:attachments]) if params[cname][:attachments]
      @item.attachments = @item.attachments # assign attachments so that it will not be queried again in model callbacks
      @item.inline_attachments = @item.inline_attachments
      @item.save_note
    end

    def render_response(success)
      if success
        render_201_with_location
      else
        render_custom_errors(@item)
      end
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields(ConversationConstants::ERROR_FIELD_MAPPINGS, item)
    end

    def can_update?
      # note without source type as 'note' should not be allowed to update
      unless @item.source == Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note']
        render_405_error(['DELETE'])
        return false
      end
      true
    end

    def load_parent_ticket # Needed here in controller to find the item by display_id
      @ticket = tickets_scoper.find_by_param(params[:id], current_account)
      log_and_render_404 unless @ticket
      @ticket
    end

    def tickets_scoper
      current_account.tickets
    end

    def load_notable_from_item
      @ticket = @item.notable
    end

    def load_object
      super scoper.conversations
    end

    def scoper
      current_account.notes
    end

    def remove_ignore_params
      params[cname].except!(ConversationConstants::IGNORE_PARAMS)
    end

    def constants_class
      ConversationConstants.to_s.freeze
    end

    def validation_class
      ConversationValidation
    end

    def validate_params
      field = "#{constants_class}::#{action_name.upcase}_FIELDS".constantize
      params[cname].permit(*field)
      @conversation_validation = validation_class.new(params[cname], @item, string_request_params?)
      valid = @conversation_validation.valid?(action_name.to_sym)
      render_errors @conversation_validation.errors, @conversation_validation.error_options unless valid
      valid
    end

    def sanitize_params
      fields = "#{action_name.upcase}_ARRAY_FIELDS"
      array_fields = ConversationConstants.const_defined?(fields) ? ConversationConstants.const_get(fields) : []
      prepare_array_fields array_fields.map(&:to_sym)

      # set source only for create/reply/forward action not for update action. Hence TYPE_FOR_ACTION is checked.
      params[cname][:source] = ConversationConstants::TYPE_FOR_ACTION[action_name] if ConversationConstants::TYPE_FOR_ACTION.keys.include?(action_name)

      # only note can have choices for private field. others will be set to false always.
      params[cname][:private] = false unless update? || params[cname][:source] == Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note']

      # Set ticket id from already assigned ticket only for create/reply/forward action not for update action.
      params[cname][:notable_id] = @ticket.id if @ticket

      ParamsHelper.assign_and_clean_params(ConversationConstants::PARAMS_MAPPINGS, params[cname])
      build_note_body_attributes
      params[cname][:attachments] = params[cname][:attachments].map { |att| { resource: att } } if params[cname][:attachments]
    end

    def check_agent_note
      render_request_error(:access_denied, 403) if @item.user && @item.user.customer?
    end

    def check_privilege
      return false unless super # break if there is no enough privilege.

      # load ticket and return 404 if ticket doesn't exists in case of APIs which has ticket_id in url
      return false if ticket_required? && !load_parent_ticket
      verify_ticket_permission(api_current_user, @ticket) if @ticket
    end

    def ticket_required?
      ConversationConstants::TICKET_LOAD_REQUIRED.include?(action_name.to_sym)
    end

    def reply?
      @reply ||= current_action?('reply')
    end

    def ticket_conversations?
      @ticket_conversation_action ||= current_action?('ticket_conversations')
    end

    def build_note_body_attributes
      if params[cname][:body]
        note_body_hash = { note_body_attributes: { body_html: params[cname][:body] } }
        params[cname].merge!(note_body_hash).tap do |t|
          t.delete(:body) if t[:body]
        end
      end
    end

    def valid_content_type?
      return true if super
      allowed_content_types = ConversationConstants::ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym] || [:json]
      allowed_content_types.include?(request.content_mime_type.ref)
    end

    def check_for_broadcast
      render_request_error(:unable_to_perform, 403) if @item.broadcast_note?
    end

    # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
    wrap_parameters(*wrap_params)
end
