module AttachmentsValidationConcern
  extend ActiveSupport::Concern

  def check_attachment_permission attachments
    attachments.each do |attachment|
      attachable_type = attachment.attachable_type
      if ['Helpdesk::Ticket', 'Helpdesk::Note'].include? attachable_type
        ticket_id = fetch_attachable_id(attachment)
        check_ticket_permission ticket_id
      elsif ['Solution::Article', 'Solution::Draft'].include? attachable_type
        return access_denied unless privilege?(:publish_solution)
      end
    end
  end

  def validate_attachments_permission
    parent_attachments
    check_attachment_permission(@account_attachments)
  end

  def check_item_permission
    return check_attachment_permission(Array(@item))
  end

  def fetch_attachable_id attachment
    if attachment.attachable_type == AttachmentConstants::ATTACHABLE_TYPES["conversation"] 
      return attachment.attachable.notable_id
    elsif attachment.attachable_type == AttachmentConstants::ATTACHABLE_TYPES["ticket"]
      return attachment.attachable_id
    end
  end

  def check_ticket_permission ticket_id
    ticket = current_account.tickets.find_by_id(ticket_id)
    if ticket.nil?
      log_and_render_404
      return false
    end
    access_denied unless current_user && (ticket.requester_id == current_user.id || ticket_privilege?(ticket))
  end

end