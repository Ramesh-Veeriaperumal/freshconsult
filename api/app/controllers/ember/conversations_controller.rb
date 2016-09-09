module Ember
  class ConversationsController < ::ConversationsController

    def create
      assign_note_attributes
      conversation_delegator = ConversationDelegator.new(@item, attachment_ids: @attachment_ids)
      if conversation_delegator.valid?
        @item.attachments = @item.attachments + conversation_delegator.draft_attachments if conversation_delegator.draft_attachments
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
        @item.attachments = @item.attachments + conversation_delegator.draft_attachments if conversation_delegator.draft_attachments
        @item.email_config_id = conversation_delegator.email_config_id
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
        build_normal_attachments(@item, params[cname][:attachments]) if params[cname][:attachments]
        @item.attachments = @item.attachments # assign attachments so that it will not be queried again in model callbacks
        @item.inline_attachments = @item.inline_attachments
      end

      def sanitize_params
        super
        # attachment_ids must be handled separately, should not be passed to build_object method
        if params[cname].key?(:attachment_ids)
          @attachment_ids = params[cname][:attachment_ids].map(&:to_i)
          params[cname].delete(:attachment_ids)
        end
      end

      def render_201_with_location(template_name: "conversations/#{action_name}", location_url: 'conversation_url', item_id: @item.id)
        render template_name, location: send(location_url, item_id), status: 201
      end

      wrap_parameters(*wrap_params)
  end
end