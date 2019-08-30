module MailboxConcern
  def outgoing_access_type?
    cname_params[:custom_mailbox] &&
      cname_params[:custom_mailbox][:access_type].present? &&
      cname_params[:custom_mailbox][:access_type] == Email::Mailbox::Constants::OUTGOING_ACCESS_TYPE
  end

  def incoming_access_type?
    cname_params[:custom_mailbox] &&
      cname_params[:custom_mailbox][:access_type].present? &&
      cname_params[:custom_mailbox][:access_type] == Email::Mailbox::Constants::INCOMING_ACCESS_TYPE
  end

  def custom_to_freshdesk_mailbox_change?
    (@item.imap_mailbox.present? || @item.smtp_mailbox.present?) && cname_params[:mailbox_type] == Email::Mailbox::Constants::FRESHDESK_MAILBOX
  end

  def imap_be_destroyed?
    custom_to_freshdesk_mailbox_change? || outgoing_access_type?
  end

  def smtp_be_destroyed?
    custom_to_freshdesk_mailbox_change? || incoming_access_type?
  end
end
