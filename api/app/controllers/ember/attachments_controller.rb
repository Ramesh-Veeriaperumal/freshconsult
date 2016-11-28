module Ember
  class AttachmentsController < ApiApplicationController
    # TODO: Common file shared between Web and API to be moved separately
    include Helpdesk::MultiFileAttachment::Util
    include DeleteSpamConcern

    skip_before_filter :check_privilege, only: [:destroy]
    before_filter :can_send_user?, only: [:create]
    before_filter :load_items, :check_destroy_permission, only: [:destroy]

    def create
      attachment_delegator = AttachmentDelegator.new(@item, user: @user, api_user: api_current_user)
      if attachment_delegator.valid?
        create_attachment
      else
        render_custom_errors(attachment_delegator, true)
      end
    end

    def self.wrap_params
      AttachmentConstants::WRAP_PARAMS
    end

    private

      def scoper
        current_account.attachments
      end

      def load_items
        @items ||= Array.wrap(@item)
      end

      def validate_params
        params[cname].permit(*AttachmentConstants::CREATE_FIELDS)
        @attachment_validation = AttachmentValidation.new(params[cname], @item, string_request_params?)
        valid = @attachment_validation.valid?
        render_errors @attachment_validation.errors, @attachment_validation.error_options unless valid
        valid
      end

      def sanitize_params
        params[cname][:attachable_type] = AttachmentConstants::STANDALONE_ATTACHMENT_TYPE
        params[cname][:user_id] ||= api_current_user.id
        ParamsHelper.assign_and_clean_params(AttachmentConstants::FIELD_MAPPINGS, params[cname])
      end

      def valid_content_type?
        return super unless create?
        AttachmentConstants::ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym].include?(request.content_mime_type.ref)
      end

      def create_attachment
        if @item.save
          mark_for_cleanup(@item.id)
        else
          render_custom_errors(@item)
        end
      end

      def post_destroy_actions(item)
        unmark_for_cleanup(item.id) if item.attachable_type == AttachmentConstants::STANDALONE_ATTACHMENT_TYPE
      end

      # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
      wrap_parameters(*wrap_params)
  end
end
