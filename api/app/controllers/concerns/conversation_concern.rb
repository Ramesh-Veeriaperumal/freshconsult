module ConversationConcern
  extend ActiveSupport::Concern

  private
    def sanitize_note_params
      sanitize_body_params
      assign_default_values
      modify_and_remove_params
      process_saved_params
    end

    def assign_default_values
      # set source only for create/reply/forward action not for update action. Hence TYPE_FOR_ACTION is checked.
      cname_params[:source] = ConversationConstants::TYPE_FOR_ACTION[action_name] if ConversationConstants::TYPE_FOR_ACTION.keys.include?(action_name)
      # only note can have choices for private field. others will be set to false always.
      cname_params[:private] = false unless update? || cname_params[:source] == Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note']
      # Set ticket id from already assigned ticket only for create/reply/forward action not for update action.
      cname_params[:notable_id] = @ticket.id if @ticket
      modify_attachment_params
      update_edit_timestamps
    end

    def modify_attachment_params
      cname_params[:attachments] = cname_params[:attachments].map { |att| { resource: att } } if cname_params[:attachments]
    end

    def update_edit_timestamps
      return unless update?
      cname_params[:last_modified_user_id] = api_current_user.id.to_s
      cname_params[:last_modified_timestamp] = Time.now.utc
    end

    def modify_and_remove_params
      ParamsHelper.assign_and_clean_params(ConversationConstants::PARAMS_MAPPINGS, cname_params)
      ParamsHelper.save_and_remove_params(self, ConversationConstants::PARAMS_TO_SAVE_AND_REMOVE, cname_params)
      modify_note_body_attributes
      ParamsHelper.clean_params(ConversationConstants::PARAMS_TO_REMOVE, cname_params)
    end

    def modify_note_body_attributes
      cname_params[:note_body_attributes] = { body_html: cname_params[:body] } if cname_params[:body]
      cname_params[:note_body_attributes][:full_text_html] = cname_params[:full_text] if cname_params[:full_text]
    end

    def process_saved_params
      # following fields must be handled separately, should not be passed to build_object method
      @attachment_ids = @attachment_ids.map(&:to_i) if @attachment_ids
      @cloud_file_ids = @cloud_file_ids.map(&:to_i) if @cloud_file_ids
      @note_id        = @note_id.to_i if @note_id
      @include_quoted_text = @include_quoted_text.to_bool if @include_quoted_text.try(:is_a?, String)
      @include_original_attachments = @include_original_attachments.to_bool if @include_original_attachments.try(:is_a?, String)
    end
end