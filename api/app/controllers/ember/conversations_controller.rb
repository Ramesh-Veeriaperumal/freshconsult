module Ember
  class ConversationsController < ::ConversationsController
    include Concerns::ApplicationViewConcern
    include Concerns::TicketsViewConcern
    include Facebook::TicketActions::Util
    include Conversations::Twitter
    include HelperConcern
    include ConversationConcern
    include AttachmentConcern
    include Utils::Sanitizer
    decorate_views(
      decorate_objects: [:ticket_conversations],
      decorate_object: [:create, :update, :reply, :forward, :facebook_reply, :tweet]
    )

    before_filter :can_send_user?, only: [:forward, :facebook_reply, :tweet]
    before_filter :set_defaults, only: [:forward]
    SINGULAR_RESPONSE_FOR = %w(reply forward create update tweet facebook_reply).freeze

    def ticket_conversations
      return if validate_filter_params(%w(order_type))
      order_type = params[:order_type]
      order_conditions = "created_at #{order_type}"
      ticket_conversations = @ticket.notes.visible.exclude_source('meta')
                                    .preload(conditional_preload_options)
                                    .order(order_conditions)
      # @items = paginate_items(ticket_conversations)
      load_objects(ticket_conversations)
      response.api_meta = { count: @items_count }
    end

    def create
      assign_note_attributes
      delegator_hash = { attachment_ids: @attachment_ids, shared_attachments: shared_attachments }
      return unless validate_delegator(@item, delegator_hash)
      is_success = save_note
      render_response(is_success)
    end

    def reply
      return unless validate_params
      sanitize_and_build
      delegator_hash = { attachment_ids: @attachment_ids, shared_attachments: shared_attachments }
      return unless validate_delegator(@item, delegator_hash)
      save_note_and_respond
    end

    def forward
      return unless validate_params
      sanitize_and_build
      delegator_hash = { parent_attachments: parent_attachments, shared_attachments: shared_attachments,
                         attachment_ids: @attachment_ids, cloud_file_ids: @cloud_file_ids }
      return unless validate_delegator(@item, delegator_hash)
      save_note_and_respond
    end

    def update
      sanitize_body_text
      assign_note_attributes
      @item.assign_attributes(cname_params)
      delegator_hash = { attachment_ids: @attachment_ids, shared_attachments: shared_attachments }
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
      return unless validate_delegator(@item, note_id: @note_id)
      is_success = reply_to_fb_ticket(@delegator.note)
      render_response(is_success)
    end

    def tweet
      @validation_klass = 'TwitterReplyValidation'
      return unless validate_body_params(@ticket)

      sanitize_params
      build_object
      assign_note_attributes

      @delegator_klass = 'TwitterReplyDelegator'
      return unless validate_delegator(@item, twitter_handle_id: @twitter_handle_id)

      if @item.save_note
        tweet_and_render
      else
        render_response(false)
      end
    end

    def reply_forward_template
      @agent_signature = signature
      @content = template_content
      @quoted_text = quoted_text(@ticket, (action_name.to_sym == :forward_template))
      render action: :template
    end

    alias reply_template reply_forward_template
    alias forward_template reply_forward_template

    private

      def sanitize_body_text
        @item.assign_element_html(cname_params[:note_body_attributes], 'body') if cname_params[:note_body_attributes]
        sanitize_body_hash(cname_params, :note_body_attributes, 'body', 'full_text') if cname_params
      end

      def conditional_preload_options
        preload_options = [:schema_less_note, :note_old_body, :attachments, :freshfone_call, :cloud_files, :attachments_sharable,
                           custom_survey_remark: { survey_result: { survey: { survey_questions: {} }, survey_result_data: {} } }]
        if @ticket.facebook?
          preload_options << :fb_post
        elsif @ticket.twitter?
          preload_options << :tweet
        end
        preload_options
      end

      def save_note_and_respond
        is_success = save_note
        # publish solution is being set in kbase_email_included based on privilege and email params
        if is_success
          create_solution_article if @publish_solution
          @ticket.draft.clear if reply?
        end
        render_response(is_success)
      end

      def sanitize_and_build
        sanitize_params
        build_object
        kbase_email_included? cname_params # kbase_email_included? present in Email module
        assign_note_attributes
      end

      def reply_to_fb_ticket(note)
        return unless @item.save_note
        fb_page     = @ticket.fb_post.facebook_page
        parent_post = note || @ticket
        if @ticket.is_fb_message?
          send_reply(fb_page, @ticket, @item, POST_TYPE[:message])
        else
          send_reply(fb_page, parent_post, @item, POST_TYPE[:comment])
        end
      end

      def assign_note_attributes
        if @item.user_id
          @item.user = @user if @user
        else
          @item.user = api_current_user
        end # assign user instead of id as the object is already loaded.
        @item.notable = @ticket # assign notable instead of id as the object is already loaded.
        @item.notable.account = current_account
        load_normal_attachments if forward?
        build_normal_attachments(@item, cname_params[:attachments])
        build_shared_attachments(@item, shared_attachments)
        build_cloud_files(@item, @cloud_files)
        @item.attachments = @item.attachments # assign attachments so that it will not be queried again in model callbacks
        @item.inline_attachments = @item.inline_attachments
      end

      def sanitize_params
        sanitize_note_params
      end

      def save_note
        # assign attributes post delegator validation
        @item.email_config_id = @delegator.email_config_id
        @item.attachments = @item.attachments + @delegator.draft_attachments if @delegator.draft_attachments
        assign_attributes_for_forward if forward?
        @item.save_note
      end

      def assign_attributes_for_forward
        @item.from_email ||= current_account.primary_email_config.reply_email
        @item.note_body.full_text_html ||= (@item.note_body.body_html || '')
        @item.note_body.full_text_html = @item.note_body.full_text_html + bind_last_conv(@ticket, signature, true) if @include_quoted_text
        load_cloud_files
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
          if @include_original_attachments
            @ticket.all_attachments
          elsif @attachment_ids
            @ticket.all_attachments.select { |x| @attachment_ids.include?(x.id) }
          end
        end
      end

      def shared_attachments
        # shared attachments explicitly included in the note
        @shared_attachments ||= begin
          attachments_to_exclude = forward? ? (parent_attachments || []).map(&:id) : []
          shared_attachment_ids = (@attachment_ids || []) - attachments_to_exclude
          return [] unless shared_attachment_ids.any?
          current_account.attachments.where('id IN (?) AND attachable_type IN (?)', shared_attachment_ids, ['Account', 'Admin::CannedResponses::Response'])
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

      def set_custom_errors(item = @item)
        fields_to_be_renamed = ConversationConstants::ERROR_FIELD_MAPPINGS
        fields_to_be_renamed.merge!(ConversationConstants::AGENT_USER_MAPPING) if agent_mapping_required?
        ErrorHelper.rename_error_fields(fields_to_be_renamed, item)
      end

      def forward?
        @forward ||= current_action?('forward')
      end

      def agent_mapping_required?
        forward? || current_action?('facebook_reply')
      end

      def set_defaults
        cname_params[:include_quoted_text] = true unless cname_params.key?(:include_quoted_text) || cname_params.key?(:full_text)
        cname_params[:include_original_attachments] = true unless cname_params.key?(:include_original_attachments)
      end

      def constants_class
        :ConversationConstants.to_s.freeze
      end

      def ember_redirect?
        [:create, :reply, :forward, :facebook_reply].include?(action_name.to_sym)
      end

      def render_201_with_location(template_name: "conversations/#{action_name}", location_url: 'conversation_url', item_id: @item.id)
        return super(location_url: location_url) if ember_redirect?
        render template_name, location: send(location_url, item_id), status: 201
      end

      def tweet_and_render
        error_msg, _tweet = send("send_tweet_as_#{@tweet_type}", @ticket, @item, @item.body)
        if error_msg
          @item.errors[:body] << :unable_to_connect_twitter
          render_response(false)
        else
          render_201_with_location(template_name: 'ember/conversations/tweet')
        end
      end

      def template_content
        parse_liquid(current_account.email_notifications
          .find_by_notification_type("EmailNotification::DEFAULT_#{action_name.upcase}".constantize)
          .try(:"get_#{action_name}", @ticket.requester).to_s
          .gsub('{{ticket.satisfaction_survey}}', ''))
      end

      def parse_liquid(liquid_content)
        Liquid::Template.parse(liquid_content).render(
          'ticket' => @ticket,
          'helpdesk_name' => Account.current.portal_name
        )
      end

      wrap_parameters(*wrap_params)
  end
end
