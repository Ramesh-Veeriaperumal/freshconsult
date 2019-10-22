module Ember
  class ConversationsController < ::ConversationsController
    include Concerns::ApplicationViewConcern
    include Concerns::TicketsViewConcern
    include Concerns::AppConfigurationConcern
    include Facebook::TicketActions::Util
    include Conversations::Twitter
    include HelperConcern
    include ConversationConcern
    include AttachmentConcern
    include Utils::Sanitizer
    include AssociateTicketsHelper
    include AttachmentsValidationConcern
    include DeleteSpamConcern
    include Redis::UndoSendRedis
    include Ecommerce::Ebay::ReplyHelper

    decorate_views(
      decorate_objects: [:ticket_conversations],
      decorate_object: %i[create update reply facebook_reply tweet broadcast ecommerce_reply]
    )

    before_filter :can_send_user?, only: %i[create reply facebook_reply ecommerce_reply tweet broadcast]
    before_filter :link_tickets_enabled?, only: [:broadcast]
    before_filter :validate_attachments_permission, only: [:create, :update]
    before_filter :check_enabled_undo_send, only: [:undo_send]

    SINGULAR_RESPONSE_FOR = %w[reply create update tweet facebook_reply broadcast ecommerce_reply].freeze
    SLAVE_ACTIONS = %w(ticket_conversations).freeze
    DUMMY_ID_FOR_UNDO_SEND_NOTE = 9_007_199_254_740_991
    QUOTED_TEXT_SPLITTER = '<div class="freshdesk_quote">'.freeze

    def ticket_conversations
      validate_filter_params
      return unless @conversation_filter.valid?

      load_conversations
      response.api_meta = { count: @items_count }
      ner_data = @ticket.fetch_ner_data
      response.api_meta = response.api_meta.merge(ner_data: ner_data) if ner_data
    end

    def create
      assign_note_attributes
      return unless validate_delegator(@item, delegator_hash)
      is_success = save_note
      render_response(is_success)
    end

    def reply
      @post_to_forum_topic = params[cname][:post_to_forum_topic]
      @last_note_id = params[:last_note_id].to_i
      @last_note_id = @ticket.notes.last.try(:id) if @last_note_id == 1
      return unless validate_params
      sanitize_and_build
      return unless validate_delegator(@item, delegator_hash)
      if current_user.enabled_undo_send?
        save_note_and_respond_later
      else
        save_note_and_respond
      end
    end

    def undo_send
      set_worker_choice_false(current_user.id, params[:id], params['created_at'].to_time.iso8601)
      remove_undo_send_traffic_cop_msg(params[:id])
      head 204
    end

    def broadcast
      return unless validate_params
      sanitize_and_build
      return unless validate_delegator(@item, { inline_attachment_ids: @inline_attachment_ids })
      save_note_and_respond
    end

    def update
      sanitize_body_text
      assign_note_attributes
      @item.assign_attributes(cname_params)
      delegator_hash = { attachment_ids: @attachment_ids, shared_attachments: shared_attachments, inline_attachment_ids: @inline_attachment_ids }
      return unless validate_delegator(@item, delegator_hash)
      render_custom_errors(@item) unless save_note
    end

    def facebook_reply
      @validation_klass = 'FbReplyValidation'
      return unless validate_body_params(@ticket)

      sanitize_params
      build_object
      assign_note_attributes
      @delegator_klass = 'FbReplyDelegator'
      fb_page = @ticket.fb_post.facebook_page

      if facebook_outgoing_attachment_enabled?
        return unless validate_delegator(@item, note_id: @note_id, fb_page: fb_page, attachment_ids: @attachment_ids, msg_type: @msg_type)

        add_facebook_attachments
      else
        return unless validate_delegator(@item, note_id: @note_id, fb_page: fb_page)
      end
      reply_sent = reply_to_fb_ticket(@delegator.note)
      is_success = (reply_sent == :fb_user_blocked) || (reply_sent == :failure) ? false : reply_sent
      render_response(is_success)
    end

    def tweet
      @validation_klass = 'TwitterReplyValidation'
      return unless validate_body_params(@ticket)

      sanitize_params
      build_object
      assign_note_attributes

      @delegator_klass = 'TwitterReplyDelegator'
      return unless validate_delegator(@item, twitter_handle_id: @twitter_handle_id, attachment_ids: @attachment_ids)

      draft_attachments = @delegator.draft_attachments
      @item.attachments = @item.attachments + draft_attachments if draft_attachments
      handle_twitter_conversations
    end

    def ecommerce_reply
      @validation_klass = 'EbayReplyValidation'
      return unless validate_body_params(@ticket)

      sanitize_params
      build_object
      assign_note_attributes
      @delegator_klass = 'EbayReplyDelegator'
      return unless validate_delegator(@item, attachment_ids: @attachment_ids)

      draft_attachments = @delegator.draft_attachments
      @item.attachments = @item.attachments + draft_attachments if draft_attachments
      handle_ebay_conversations
    end

    def reply_forward_template
      @item = last_forwardable_note if action_name.to_sym == :latest_note_forward_template
      @ticket.escape_liquid_attributes = current_account.launched?(:escape_liquid_for_reply)
      if params.key?(:body)
        time = params[:time]
        body_html = get_reply_template_content(current_user.id, @ticket.display_id, time)
        full_text_html = get_quoted_content(current_user.id, @ticket.display_id, time)
        attachments = (params[:attachments].map do |att|
          current_account.attachments.where(id: att['id']).first
        end).compact
        @inline_attachment_ids = params[:inline].map(&:to_i)
        @attachments = attachments
        @content = body_html
        @quoted_text = compute_quoted_text(full_text_html)
        @quoted_text = nil if @quoted_text.blank?
        @cc_emails = params[:cc]
        @bcc_emails = params[:bcc]
        @agent_signature = ''
        delete_body_data(current_user.id, @ticket.display_id, time)
      else
        @agent_signature = signature
        @content = template_content
        @quoted_text = quoted_text(@item || @ticket, forward_template?)
        fetch_to_cc_bcc_emails
      end
      Rails.logger.info "cc_emails: #{@cc_emails.inspect}" if @cc_emails.present?
      @cc_emails.clear if forward_template?
      fetch_attachments
      render action: :template
    end

    alias reply_template reply_forward_template
    alias forward_template reply_forward_template
    alias note_forward_template reply_forward_template
    alias latest_note_forward_template reply_forward_template
    alias reply_to_forward_template reply_forward_template

    private

      def add_facebook_attachments
        @item.attachments = @item.attachments + @delegator.draft_attachments if @delegator.draft_attachments
      end

      def fetch_attachments
        return unless forward_template?
        @attachments = (@item || @ticket).attachments
        @cloud_attachments = (@item || @ticket).cloud_files
      end

      def forward_template?
        [:forward_template, :note_forward_template, :latest_note_forward_template].include?(action_name.to_sym)
      end

      def load_conversations
        order_type = params[:order_type]
        order_conditions = "created_at #{order_type}"
        since_id = params[:since_id] && params[:since_id].to_i <= 0 ? nil : params[:since_id]
        conversations = @ticket.notes.conversations(conditional_preload_options,order_conditions)
        filtered_conversations = if since_id
                                   last_created_at = @ticket.notes.where(id: since_id).pluck(:created_at).first
                                   conversations.created_since(since_id, last_created_at)
                                 else
                                   conversations
                                 end

        @items = paginate_items(filtered_conversations)
        @items_count = conversations.count
      end

      def index?
        @index ||= (current_action?('index') || current_action?('ticket_conversations'))
      end

      def broadcast?
        @broadcast ||= current_action?('broadcast')
      end

      def decorator_options
        options = {}
        options[:sideload_options] = sideload_options
        super(options)
      end

      def sideload_options
        @conversation_filter.try(:include_array) || []
      end

      def sanitize_body_text
        @item.assign_element_html(cname_params[:note_body_attributes], 'body') if cname_params[:note_body_attributes]
        sanitize_body_hash(cname_params, :note_body_attributes, 'body', 'full_text') if cname_params
      end

      def conditional_preload_options
        preload_options = [:schema_less_note, :note_old_body, :attachments, :cloud_files, :attachments_sharable,
                           custom_survey_remark: { survey_result: { survey: { survey_questions: {} }, survey_result_data: {} } }]
        if @ticket.facebook?
          preload_options << :fb_post
        elsif @ticket.twitter?
          preload_options << :tweet
        end
        preload_options << :freshfone_call if current_account.freshfone_enabled?
        preload_options << :freshcaller_call if current_account.freshcaller_enabled?
        preload_options << [{ user: [:avatar, :user_companies, :user_emails, :tags] }] if sideload_options.include?('requester')
        preload_options
      end

      def save_note_and_respond_later
        is_success = save_note_later
        @ticket.draft.clear if reply?
        set_dummy_note_id
        render_response(is_success)
      end

      def save_note_and_respond
        is_success = save_note
        # publish solution is being set in kbase_email_included based on privilege and email params
        if is_success
          create_solution_article if @publish_solution
          @ticket.draft.clear if reply?
        end
        @ticket.add_forum_post(@item) if @post_to_forum_topic
        render_response(is_success)
      end

      def sanitize_and_build
        sanitize_params
        build_object
        kbase_email_included? cname_params # kbase_email_included? present in Email module
        assign_note_attributes
      end

      def reply_to_fb_ticket(note)
        fb_page     = @ticket.fb_post.facebook_page
        parent_post = note || @ticket
        if skip_posting_to_fb
          build_fb_association(parent_post) 
          return @item.save_note
        end

        return unless @item.save_note

        reply_sent = send_reply_to_fb(fb_page, parent_post)
        if reply_sent == :fb_user_blocked
          @item.errors[:body] << :facebook_user_blocked
        else
          @item.errors[:body] << :unable_to_perform
        end
        reply_sent
      end

      def build_fb_association(parent_post)
        association_hash = @ticket.is_fb_message? ? construct_dm_hash(@ticket) : construct_post_hash(parent_post)
        @item.build_fb_post(association_hash)
      end

      def send_reply_to_fb(fb_page, parent_post)
        if @ticket.is_fb_message?
          return send_reply(fb_page, @ticket, @item, POST_TYPE[:message])
        else
          return send_reply(fb_page, parent_post, @item, POST_TYPE[:comment])
        end
      end

      def assign_note_attributes
        # assign user instead of id as the object is already loaded.
        assign_user @item
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

      def sanitize_params
        sanitize_note_params
      end

      def validate_filter_params
        @constants_klass = 'ConversationConstants'
        @validation_klass = 'ConversationFilterValidation'
        validate_query_params
        @conversation_filter = @validator
      end

      def save_note
        assign_extras
        @item.save_note
      end

      def save_note_later
        assign_extras
        @item.save_note_later(@publish_solution, @post_to_forum_topic)
      end

      def assign_from_email
        return unless reply?
        if @delegator.email_config
          @item.email_config_id = @delegator.email_config.id
          @item.from_email = current_account.features?(:personalized_email_replies) ? @delegator.email_config.friendly_email_personalize(current_user.name) : @delegator.email_config.friendly_email
        else
          @item.from_email = current_account.features?(:personalized_email_replies) ? @ticket.friendly_reply_email_personalize(current_user.name) : @ticket.selected_reply_email
        end
      end

      def load_normal_attachments
        attachments_array = cname_params[:attachments] || []
        (parent_attachments || []).each do |attach|
          attachments_array.push(resource: attach.to_io)
        end
        cname_params[:attachments] = attachments_array
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
          shared_attachment_ids = (@attachment_ids || [])
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
          .try(:parsed_signature, 'ticket' => @ticket, 'helpdesk_name' => Account.current.helpdesk_name)
      end

      def set_custom_errors(item = @item)
        fields_to_be_renamed = ConversationConstants::ERROR_FIELD_MAPPINGS
        fields_to_be_renamed = fields_to_be_renamed.merge(ConversationConstants::AGENT_USER_MAPPING) if agent_mapping_required?
        ErrorHelper.rename_error_fields(fields_to_be_renamed, item)
      end

      def agent_mapping_required?
        current_action?('facebook_reply')
      end

      def set_defaults
        cname_params[:include_quoted_text] = true unless cname_params.key?(:include_quoted_text) || cname_params.key?(:full_text)
        cname_params[:include_original_attachments] = true unless cname_params.key?(:include_original_attachments)
      end

      def constants_class
        :ConversationConstants.to_s.freeze
      end

      def delegator_hash
        { parent_attachments: parent_attachments, attachment_ids: @attachment_ids, shared_attachments: shared_attachments, inline_attachment_ids: @inline_attachment_ids }
      end

      def ember_redirect?
        %i[create reply facebook_reply ecommerce_reply broadcast].include?(action_name.to_sym)
      end

      def render_201_with_location(template_name: "conversations/#{action_name}", location_url: 'conversation_url', item_id: @item.id)
        return super(location_url: location_url) if ember_redirect?
        render template_name, location: safe_send(location_url, item_id), status: 201
      end

      def handle_ebay_conversations
        if @item.save_note
          message = Ecommerce::Ebay::Api.new(ebay_account_id: @ticket.ebay_question.ebay_account_id).make_ebay_api_call(:reply_to_buyer, ticket: @ticket, note: @item)
          @item.build_ebay_question(user_id: current_user.id, item_id: @ticket.ebay_question.item_id, ebay_account_id: @ticket.ebay_question.ebay_account_id, account_id: @ticket.account_id)
          if message && @item.ebay_question.save
            Ecommerce::EbayMessageWorker.perform_async(ebay_account_id: @ticket.ebay_question.ebay_account_id, ticket_id: @ticket.id, note_id: @item.id, start_time: message[:timestamp].to_time)
            render_response(true)
          else
            @item.deleted = true
            @item.save
            @item.errors.add(:base, 'ebay_note_not_added')
            render_response(false)
          end
        else
          @item.errors.add(:base, 'ebay_note_not_added')
          render_response(false)
        end
      end

      def handle_twitter_conversations
        reply_handle = current_account.twitter_handles.find_by_id(@twitter_handle_id)
        stream = fetch_stream(reply_handle, @tweet_type)
        tweet_id = random_tweet_id
        if dm_note? || outgoing_tweets_in_tms?(stream)
          stream_id = stream.id
          @item.build_tweet(tweet_id: tweet_id,
                            tweet_type: @tweet_type,
                            twitter_handle_id: @twitter_handle_id, stream_id: stream_id)
        end
        if @item.save_note
          if stream.custom_stream? || (!current_account.outgoing_tweets_to_tms_enabled? && mention_note?)
            Social::TwitterReplyWorker.perform_async(ticket_id: @ticket.id, note_id: @item.id,
                                                     tweet_type: @tweet_type,
                                                     twitter_handle_id: @twitter_handle_id)
          end
          render_201_with_location(template_name: 'ember/conversations/tweet')
        else
          render_response(false)
        end
      end

      def template_content
        return '' if [:reply_to_forward_template].include?(action_name.to_sym)
        parse_liquid(current_account.email_notifications
          .find_by_notification_type("EmailNotification::DEFAULT_#{notification_template.to_s.upcase}".constantize)
          .try(:"get_#{notification_template.to_s}", @ticket.requester).to_s
          .gsub('{{ticket.satisfaction_survey}}', ''))
      end

      def notification_template
        %i(note_forward_template latest_note_forward_template).include?(action_name.to_sym) ? :forward_template : action_name.to_sym
      end

      def fetch_to_cc_bcc_emails
        if action_name == 'reply_to_forward_template'
          load_note_reply_cc = @item.load_note_reply_cc
          @to_emails     = load_note_reply_cc.last
          @cc_emails     = load_note_reply_cc.first
        else
          @cc_emails = reply_cc_emails(@ticket)
        end
        @bcc_emails = bcc_drop_box_email
      end

      def parse_liquid(liquid_content)
        @ticket.escape_liquid_attributes = current_account.launched?(:escape_liquid_for_reply)
        Liquid::Template.parse(liquid_content).render(
          'ticket' => @ticket,
          'helpdesk_name' => Account.current.helpdesk_name
        )
      end

      def last_forwardable_note
        @ticket.public_notes.where(['source NOT IN (?)', Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['feedback']]).last
      end

      def after_load_object
        load_notable_from_item # find ticket in case of APIs which has @item.id in url
        return false if check_ticket_action_permissions
        check_agent_note if update? || destroy?
      end

      def load_parent_ticket
        @ticket = tickets_scoper.find_by_param(params[:id], current_account)
        unless @ticket
          archive_ticket = if current_account.features_included?(:archive_tickets)
          archive_tickets_scoper.find_by_display_id(params[:id])
          else
            nil
          end
          (archive_ticket.present?) ? log_and_render_301_archive : log_and_render_404
        end
        @ticket
      end

      def log_and_render_301_archive
        Rails.logger.debug "The ticket is archived. Id: #{params[:id]}, method: #{params[:action]}, controller: #{params[:controller]}"
        redirect_to archive_ticket_link, status: 301
        head 301
      end

      def archive_ticket_link
        redirect_link = "/api/_/tickets/archived/#{params[:id]}/conversations"
        (archive_params.present?) ? "#{redirect_link}?#{archive_params}": redirect_link
      end

      def archive_params
        include_params = params.select{|k,v| ConversationConstants::PERMITTED_ARCHIVE_FIELDS.include?(k)}
        include_params.to_query
      end

      def archive_tickets_scoper
        current_account.archive_tickets
      end

      def check_ticket_action_permissions
        (@ticket && (!verify_ticket_state ||
          verify_ticket_permission(api_current_user, @ticket))) || # Verify ticket permission if ticket exists.
          (update? && !can_update?)
      end

      def verify_ticket_state
        if (update? || destroy?) && (@ticket.spam || @ticket.deleted)
          render_request_error(:access_denied, 403)
          return false
        end
        true
      end

      def tickets_scoper
        return super if ConversationConstants::TICKET_STATE_CHECK_NOT_REQUIRED.include?(action_name.to_sym)
        super.where(ApiTicketConstants::CONDITIONS_FOR_TICKET_ACTIONS)
      end

      def assign_extras
        draft_attachments = @delegator.draft_attachments
        @item.attachments = @item.attachments + draft_attachments if draft_attachments
        @item.inline_attachment_ids = @inline_attachment_ids if @inline_attachment_ids
        assign_from_email
      end

      def compute_quoted_text(full_text_html)
        if full_text_html.present?
          quoted_content = full_text_html.split(QUOTED_TEXT_SPLITTER, 2)[1]
          quoted_content = QUOTED_TEXT_SPLITTER + quoted_content unless quoted_content.nil?
          quoted_content
        end
      end

      def check_enabled_undo_send
        render_request_error(:access_denied, 403) unless current_user.enabled_undo_send?
      end

      def set_dummy_note_id
        # for undo_send, since we don't have a note id for 10 seconds,
        # we are rendering a note with dummy note id with the maximum integer limit in javascipt
        @item.id = DUMMY_ID_FOR_UNDO_SEND_NOTE - @ticket.display_id
      end

      def fetch_stream(reply_handle, tweet_type)
        tweet = @ticket.tweet
        tweet_stream = tweet.stream if tweet.present?
        if tweet_stream && tweet_stream.custom_stream?
          tweet_stream
        elsif tweet_type == Social::Twitter::Constants::TWITTER_NOTE_TYPE[:dm]
          reply_handle.dm_stream
        else
          reply_handle.default_stream
        end
      end

      def outgoing_tweets_in_tms?(stream)
        current_account.outgoing_tweets_to_tms_enabled? && stream.default_stream?
      end

      def dm_note?
        @tweet_type == Social::Twitter::Constants::TWITTER_NOTE_TYPE[:dm]
      end

      def mention_note?
        @tweet_type == Social::Twitter::Constants::TWITTER_NOTE_TYPE[:mention]
      end

      wrap_parameters(*wrap_params)
  end
end
