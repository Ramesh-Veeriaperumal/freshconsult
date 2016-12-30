module Ember
  class AttachmentsController < ApiApplicationController
    # TODO: Common file shared between Web and API to be moved separately
    include Helpdesk::MultiFileAttachment::Util
    include DeleteSpamConcern
    include HelperConcern

    decorate_views

    skip_before_filter :check_privilege, only: [:destroy]
    before_filter :can_send_user?, only: [:create]
    before_filter :load_items, :check_destroy_permission, only: [:destroy]

    def create
      return unless validate_delegator(@item, user: @user, api_user: api_current_user)
      create_attachment
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
        validate_body_params(@item)
      end

      def sanitize_params
        if params[cname][:inline] && params[cname][:inline].to_s == 'true'
          params[cname][:attachable_type] = "#{AttachmentConstants::INLINE_ATTACHABLE_NAMES_BY_KEY[params[cname][:inline_type].to_i]} Upload"
          params[cname][:description] = !public_upload? && one_hop? ? 'private' : 'public'
        else
          params[cname][:attachable_type] = AttachmentConstants::STANDALONE_ATTACHMENT_TYPE
          params[cname][:user_id] ||= api_current_user.id
        end
        ParamsHelper.assign_and_clean_params(AttachmentConstants::PARAMS_MAPPINGS, params[cname])
        ParamsHelper.clean_params(AttachmentConstants::PARAMS_TO_REMOVE, params[cname])
      end

      def public_upload?
        [:forum, :solution].include?( AttachmentConstants::INLINE_ATTACHABLE_TOKEN_BY_KEY[params[cname][:inline_type].to_i])
      end

      def one_hop?
        current_account.features_included?(:inline_images_with_one_hop)
      end

      def valid_content_type?
        return super unless create?
        AttachmentConstants::ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym].include?(request.content_mime_type.ref)
      end

      def create_attachment
        if @item.save
          mark_for_cleanup(@item.id) if @item.attachable_type == AttachmentConstants::STANDALONE_ATTACHMENT_TYPE
        else
          render_custom_errors(@item)
        end
      end

      def post_destroy_actions(item)
        unmark_for_cleanup(item.id) if item.attachable_type == AttachmentConstants::STANDALONE_ATTACHMENT_TYPE
      end

      def constants_class
        :AttachmentConstants.to_s.freeze
      end

      # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
      wrap_parameters(*wrap_params)
  end
end
