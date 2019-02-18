module Ember
  class AttachmentsController < ApiApplicationController
    # TODO: Common file shared between Web and API to be moved separately
    include Helpdesk::MultiFileAttachment::Util
    include DeleteSpamConcern
    include HelperConcern
    include AttachmentsValidationConcern

    decorate_views

    skip_before_filter :check_privilege, only: [:unlink]
    before_filter :can_send_user?, only: [:create]
    before_filter :validate_body_params, :load_ticket, :load_shared, :check_unlink_permission, only: [:unlink]
    before_filter :check_item_permission, only: [:show]

    def create
      return unless validate_delegator(@item, user: @user, api_user: api_current_user)
      render_custom_errors(@item) && return unless @item.save
    end

    def unlink
      @item.destroy
      head 204
    end

    def self.wrap_params
      AttachmentConstants::WRAP_PARAMS
    end

    private

      def scoper
        current_account.attachments
      end

      def check_shared
        access_denied unless @item.shared_attachments.count.zero?
      end

      def load_items
        @items ||= Array.wrap(@item)
      end

      def load_shared
        @item = Helpdesk::SharedAttachment.find_by_attachment_id(
          params[:id],
          conditions: ['shared_attachable_id=? AND shared_attachable_type=?', shared_attachable_id, shared_attachable_type]
        )
        log_and_render_404 unless @item
      end

      def load_ticket
        if ['Helpdesk::Ticket', 'Helpdesk::Note'].include?(shared_attachable_type)
          @ticket = if shared_attachable_type == 'Helpdesk::Ticket'
                      current_account.tickets.find_by_display_id(params[cname][:attachable_id])
                    elsif shared_attachable_type == 'Helpdesk::Note'
                      current_account.notes.find_by_id(params[cname][:attachable_id])
                    end
          log_and_render_404 unless @ticket
        end
      end

      def shared_attachable_id
        shared_attachable_type == 'Helpdesk::Ticket' ? @ticket.id : params[cname][:attachable_id]
      end

      def shared_attachable_type
        AttachmentConstants::ATTACHABLE_TYPES[params[cname][:attachable_type]]
      end

      def validate_params
        if replace_content_with_file?
          params[:content] = params.delete(:file)
          cname_params[:content] = cname_params.delete(:file)
        end
        validate_body_params(@item)
      end

      def replace_content_with_file?
        private_api? && params[:content].blank? && params[:file].present?
      end

      def sanitize_params
        if params[cname][:inline] && params[cname][:inline].to_s == 'true'
          params[cname][:attachable_type] = "#{AttachmentConstants::INLINE_ATTACHABLE_NAMES_BY_KEY[params[cname][:inline_type].to_i]} Upload"
          params[cname][:description] = public_upload? ? 'public' : 'private'
        else
          params[cname][:attachable_type] = AttachmentConstants::STANDALONE_ATTACHMENT_TYPE
          params[cname][:user_id] ||= api_current_user.id
        end
        ParamsHelper.assign_and_clean_params(AttachmentConstants::PARAMS_MAPPINGS, params[cname])
        ParamsHelper.clean_params(AttachmentConstants::PARAMS_TO_REMOVE, params[cname])
      end

      def public_upload?
        [:forum, :solution].include?(AttachmentConstants::INLINE_ATTACHABLE_TOKEN_BY_KEY[params[cname][:inline_type].to_i])
      end

      def valid_content_type?
        return super unless create?
        AttachmentConstants::ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym].include?(request.content_mime_type.ref)
      end

      def check_unlink_permission
        can_unlink = false
        if ['Helpdesk::Ticket', 'Helpdesk::Note'].include? shared_attachable_type
          can_unlink = true if current_user && (@ticket.requester_id == current_user.id || ticket_privilege?(@ticket))
        elsif ['Helpdesk::TicketTemplate'].include? shared_attachable_type
          can_unlink = template_priv? @item.shared_attachable
        end
        access_denied unless can_unlink
      end

      def constants_class
        :AttachmentConstants.to_s.freeze
      end

      # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
      wrap_parameters(*wrap_params)
  end
end
