module Ember
  class ConversationsController < ::ConversationsController
    include Concerns::ApplicationViewConcern
    include Concerns::TicketsViewConcern
    before_filter :can_send_user?, :set_defaults, only: [:forward]

    def create
      assign_note_attributes
      conversation_delegator = ConversationDelegator.new(@item, attachment_ids: @attachment_ids)
      if conversation_delegator.valid?
        assign_conversation_attributes(conversation_delegator)
        is_success = @item.save_note
        render_response(is_success)
      else
        render_custom_errors(conversation_delegator, true)
      end
    end

    def reply
      return unless validate_params
      sanitize_params
      build_object
      kbase_email_included? params[cname] # kbase_email_included? present in Email module
      assign_note_attributes
      conversation_delegator = ConversationDelegator.new(@item, attachment_ids: @attachment_ids)
      if conversation_delegator.valid?
        assign_conversation_attributes(conversation_delegator)
        is_success = @item.save_note
        # publish solution is being set in kbase_email_included based on privilege and email params
        create_solution_article if is_success && @publish_solution
        render_response(is_success)
      else
        render_custom_errors(conversation_delegator, true)
      end
    end

    def forward
      return unless validate_params
      sanitize_params
      build_object
      kbase_email_included? params[cname] # kbase_email_included? present in Email module
      assign_note_attributes
      delegator_hash = {attachment_ids: @attachment_ids, cloud_file_ids: @cloud_file_ids, 
                        parent_attachments: parent_attachments, include_original_attachments: @include_original_attachments}
      conversation_delegator = ConversationDelegator.new(@item, delegator_hash)
      if conversation_delegator.valid?
        assign_conversation_attributes(conversation_delegator)
        is_success = @item.save_note
        # publish solution is being set in kbase_email_included based on privilege and email params
        create_solution_article if is_success && @publish_solution
        render_response(is_success)
      else
        render_custom_errors(conversation_delegator, true)
      end
    end

    private

      def assign_note_attributes
        if @item.user_id
          @item.user = @user if @user
        else
          @item.user = api_current_user
        end # assign user instead of id as the object is already loaded.
        @item.notable = @ticket # assign notable instead of id as the object is already loaded.
        @item.notable.account = current_account
        load_normal_attachments if forward?
        build_normal_attachments(@item, params[cname][:attachments])
        @item.attachments = @item.attachments # assign attachments so that it will not be queried again in model callbacks
        @item.inline_attachments = @item.inline_attachments
      end

      def sanitize_params
        super
        # following fields must be handled separately, should not be passed to build_object method
        assign_and_remove_params([:attachment_ids, :cloud_file_ids, :include_quoted_text, :include_original_attachments])
        @attachment_ids = @attachment_ids.map(&:to_i) if @attachment_ids
        @cloud_file_ids = @cloud_file_ids.map(&:to_i) if @cloud_file_ids
        @include_quoted_text = @include_quoted_text.to_bool if @include_quoted_text && @include_quoted_text.is_a?(String)
        @include_original_attachments = @include_original_attachments.to_bool if @include_original_attachments && @include_original_attachments.is_a?(String)
      end

      def assign_and_remove_params(fields)
        fields.each do |field|
          instance_variable_set("@#{field}", params[cname].delete(field)) if params[cname].key?(field)
        end
      end

      def load_normal_attachments
        attachments_array = params[cname][:attachments] || []
        (parent_attachments || []).each do |attach|
          url = attach.authenticated_s3_get_url
          io  = open(url)
          if io
            def io.original_filename; base_uri.path.split('/').last.gsub("%20"," "); end
          end
          attachments_array.push({resource: io})
        end
        params[cname][:attachments] = attachments_array
      end

      def build_cloud_files(delegator_item)
        (parent_cloud_files(delegator_item) || []).each do |cloud_file|
          @item.cloud_files.build({ url:cloud_file.url, filename: cloud_file.filename, application_id: cloud_file.application_id })
        end
      end

      def parent_attachments
        @parent_attachments ||= begin
          if @include_original_attachments
            @ticket.attachments
          elsif @attachment_ids
            @ticket.attachments.where(id: @attachment_ids)
          end
        end
      end

      def parent_cloud_files(delegator_item)
        if @include_original_attachments
          @ticket.cloud_files
        elsif @cloud_file_ids
          delegator_item.cloud_file_attachments
        end
      end

      def assign_conversation_attributes(conversation_delegator)
        @item.email_config_id = conversation_delegator.email_config_id
        @item.attachments = @item.attachments + conversation_delegator.draft_attachments if conversation_delegator.draft_attachments
        return unless forward?
        @item.from_email ||= current_account.primary_email_config.reply_email
        @item.note_body.full_text_html = (@item.note_body.body_html || "")
        @item.note_body.full_text_html = @item.note_body.full_text_html + bind_last_conv(@ticket, signature, true) if @include_quoted_text
        build_cloud_files(conversation_delegator)
      end

      def signature
        agent = (@user || api_current_user).agent
        agent ? agent.signature_value : ""
      end

      def set_custom_errors(item = @item)
        fields_to_be_renamed = ConversationConstants::ERROR_FIELD_MAPPINGS
        fields_to_be_renamed.merge!(ConversationConstants::FORWARD_FIELD_MAPPINGS) if forward?
        ErrorHelper.rename_error_fields(fields_to_be_renamed, item)
      end

      def forward?
        @forward ||= current_action?('forward')
      end

      def set_defaults
        params[cname][:include_quoted_text] = true unless params[cname].key?(:include_quoted_text)
        params[cname][:include_original_attachments] = true unless params[cname].key?(:include_original_attachments)
      end

      def render_201_with_location(template_name: "conversations/#{action_name}", location_url: 'conversation_url', item_id: @item.id)
        return super(location_url: location_url) if forward?
        render template_name, location: send(location_url, item_id), status: 201
      end

      wrap_parameters(*wrap_params)
  end
end