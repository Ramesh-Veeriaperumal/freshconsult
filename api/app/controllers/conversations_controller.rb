class ConversationsController < ApiApplicationController
  include TicketConcern
  include CloudFilesHelper
  include Conversations::Email
  include Conversations::Twitter
  include Facebook::TicketActions::Util
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
    return perform_social_reply if fb_public_api? || twitter_public_api?

    conversation_delegator = ConversationDelegator.new(@item, notable: @ticket)
    if conversation_delegator.valid?
      @item.email_config_id = conversation_delegator.email_config_id
      if @item.email_config_id
        @item.from_email = current_account.features?(:personalized_email_replies) ? conversation_delegator.email_config.friendly_email_personalize(current_user.name) : conversation_delegator.email_config.friendly_email
      else
        @item.from_email = current_account.features?(:personalized_email_replies) ? @ticket.friendly_reply_email_personalize(current_user.name) : @ticket.selected_reply_email
      end
      is_success = create_note
      # publish solution is being set in kbase_email_included based on privilege and email params
      create_solution_article if is_success && @create_solution_privilege
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
    @item.deleted = true
    @item.save!
    head 204
  end

  def ticket_conversations
    return if validate_filter_params
    preload_options = [:schema_less_note, :note_old_body, :attachments]
    if @ticket.facebook?
      preload_options << :fb_post
    elsif @ticket.twitter?
      preload_options << :tweet
    end
    ticket_conversations = @ticket.notes.conversations(preload_options, :created_at)
    @items = paginate_items(ticket_conversations)
  end

  def self.wrap_params
    ConversationConstants::WRAP_PARAMS
  end

  private

    def perform_social_reply
      conversation_delegator = ConversationDelegator.new(@item, fetch_delegation_hash)
      if conversation_delegator.valid?(action_name.to_sym)
        @delegator_note = conversation_delegator.parent_note
        if twitter_public_api?
          @delegator_tweet_type = conversation_delegator.tweet_type
          @delegator_twitter_handle_id = conversation_delegator.twitter_handle.id
        end
        is_success = create_note
        render_response(is_success)
      else
        render_custom_errors(conversation_delegator, true)
      end
    end

    def decorator_options(options = {})
      options[:ticket] = @ticket
      super(options)
    end

    def after_load_object
      load_notable_from_item # find ticket in case of APIs which has @item.id in url
      return false if @ticket && !verify_ticket_permission(api_current_user, @ticket, @item) # Verify ticket permission if ticket exists.
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
      build_social_associations if fb_public_api?
      return build_twitter_association if twitter_public_api?

      @item.save_note
    end

    def build_social_associations
      build_fb_association if fb_public_api?
    end

    def build_twitter_association
      reply_handle = current_account.twitter_handles.find_by_id(@delegator_twitter_handle_id)
      stream = fetch_stream(reply_handle, @ticket, @delegator_tweet_type)
      tweet_id = random_tweet_id
      custom_twitter_stream_tweet_reply = custom_twitter_stream_tweet_reply?(stream, @delegator_tweet_type)
      unless custom_twitter_stream_tweet_reply
        stream_id = stream.id
        @item.build_tweet(tweet_id: tweet_id,
                          tweet_type: @delegator_tweet_type,
                          twitter_handle_id: @delegator_twitter_handle_id,
                          stream_id: stream_id)
      end
      result = @item.save_note
      if result && custom_twitter_stream_tweet_reply
        Social::TwitterReplyWorker.perform_async(ticket_id: @ticket.id, note_id: @item.id,
                                                 tweet_type: @delegator_tweet_type,
                                                 twitter_handle_id: @delegator_twitter_handle_id)
      end
      result
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
      unless @item.source == current_account.helpdesk_sources.note_source_keys_by_token['note']
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

    def fb_public_api?
      public_api? && Account.current.launched?(:facebook_public_api) && (@ticket[:source] == Account.current.helpdesk_sources.ticket_source_keys_by_token[:facebook]) && reply?
    end

    def twitter_public_api?
      public_api? && Account.current.launched?(:twitter_public_api) && (@ticket[:source] == Account.current.helpdesk_sources.ticket_source_keys_by_token[:twitter]) && reply?
    end

    def validate_params
      if fb_public_api? || twitter_public_api?
        fields = ConversationConstants::PUBLIC_API_FIELDS[@ticket[:source]] if ConversationConstants::PUBLIC_API_FIELDS.key?(@ticket[:source])
        params[cname].permit(*fields)
        @conversation_validation = validation_class.new(fetch_validation_hash, @item, string_request_params?)
      else
        field = "#{constants_class}::#{action_name.upcase}_FIELDS".constantize
        params[cname].permit(*field)
        @conversation_validation = validation_class.new(params[cname], @item, string_request_params?)
      end
      valid = @conversation_validation.valid?(action_name.to_sym)
      render_errors @conversation_validation.errors, @conversation_validation.error_options unless valid
      valid
    end

    def sanitize_params
      fields = "#{action_name.upcase}_ARRAY_FIELDS"
      array_fields = ConversationConstants.const_defined?(fields) ? ConversationConstants.const_get(fields) : []
      prepare_array_fields array_fields.map(&:to_sym)

      # set source only for create/reply/forward action not for update action. Hence TYPE_FOR_ACTION is checked.
      params[cname][:source] = assign_source if ConversationConstants::TYPE_FOR_ACTION.key?(action_name)

      # only note can have choices for private field. others will be set to false always.
      params[cname][:private] = false unless assign_private

      # Set ticket id from already assigned ticket only for create/reply/forward action not for update action.
      params[cname][:notable_id] = @ticket.id if @ticket

      ParamsHelper.assign_and_clean_params(ConversationConstants::PARAMS_MAPPINGS, params[cname])
      ParamsHelper.save_and_remove_params(self, [:parent_note_id, :twitter], params[cname]) if fb_public_api? || twitter_public_api?
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
      verify_ticket_permission(api_current_user, @ticket) if @ticket && !create?
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

    def assign_source
      fb_public_api? || twitter_public_api? ? Account.current.helpdesk_sources.ticket_note_source_mapping[@ticket[:source]] : ConversationConstants::TYPE_FOR_ACTION[action_name]
    end

    def assign_private
      update? || params[cname][:source] == current_account.helpdesk_sources.note_source_keys_by_token['note']
    end

    def fetch_delegation_hash
      respond_to?("#{Account.current.helpdesk_sources.ticket_source_names_by_key[@ticket[:source]]}_delegation_hash".to_sym, true) ? safe_send("#{Account.current.helpdesk_sources.ticket_source_names_by_key[@ticket[:source]]}_delegation_hash") : { notable: @ticket }
    end

    def facebook_source_delegation_hash
      {
        notable: @ticket,
        parent_note_id: @parent_note_id,
        attachments: params[cname][:attachments],
        fb_page: @ticket.fb_post.facebook_page,
        msg_type: @ticket.fb_post.msg_type,
        ticket_source: @ticket.source
      }
    end

    def twitter_source_delegation_hash
      {
        notable: @ticket,
        body: params[cname][:note_body_attributes][:body_html],
        tweet_type: @twitter.is_a?(Hash) && @twitter.try(:[], :tweet_type) ? @twitter[:tweet_type] : @ticket.tweet.tweet_type,
        twitter_handle_id: @twitter.is_a?(Hash) && @twitter.try(:[], :twitter_handle_id) ? @twitter[:twitter_handle_id] : fetch_handle_id,
        attachments: params[cname][:attachments],
        ticket_source: @ticket.source
      }
    end

    def fetch_handle_id
      @ticket.tweet.twitter_handle.twitter_user_id if @ticket.tweet.present? && @ticket.tweet.twitter_handle.present? && @ticket.tweet.twitter_handle.twitter_user_id.present?
    end

    def facebook_source_validation_hash
      params[cname].merge(ticket_source: @ticket.source, msg_type: @ticket.fb_post.msg_type)
    end

    def twitter_source_validation_hash
      params[cname].merge(twitter: params[cname][:twitter]) unless params[cname][:twitter].nil?
      params[cname].merge(ticket_source: @ticket.source)
    end

    def fetch_validation_hash
      respond_to?("#{Account.current.helpdesk_sources.ticket_source_names_by_key[@ticket[:source]]}_validation_hash".to_sym, true) ? safe_send("#{Account.current.helpdesk_sources.ticket_source_names_by_key[@ticket[:source]]}_validation_hash") : params[cname]
    end

    def build_fb_association
      parent_post = @delegator_note || @ticket
      association_hash = @ticket.is_fb_message? ? construct_dm_hash(@ticket) : construct_post_hash(parent_post)
      @item.build_fb_post(association_hash)
    end

    def build_object
      super
      verify_ticket_permission(api_current_user, @ticket, @item) if @ticket && create?
    end

    wrap_parameters(*wrap_params)
end
