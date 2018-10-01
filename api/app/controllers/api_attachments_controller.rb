class ApiAttachmentsController < ApiApplicationController
  include Helpdesk::MultiFileAttachment::Util
  include DeleteSpamConcern
  include HelperConcern

  skip_before_filter :check_privilege, only: [:destroy]
  before_filter :check_shared, :load_items, :check_destroy_permission, only: [:destroy]

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

    def constants_class
      :AttachmentConstants.to_s.freeze
    end
end
