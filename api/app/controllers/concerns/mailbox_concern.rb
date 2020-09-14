module MailboxConcern
  include Email::Mailbox::Constants

  def outgoing_access_type?
    cname_params[:custom_mailbox] &&
      cname_params[:custom_mailbox][:access_type].present? &&
      cname_params[:custom_mailbox][:access_type] == OUTGOING_ACCESS_TYPE
  end

  def incoming_access_type?
    cname_params[:custom_mailbox] &&
      cname_params[:custom_mailbox][:access_type].present? &&
      cname_params[:custom_mailbox][:access_type] == INCOMING_ACCESS_TYPE
  end

  def both_access_type?
    cname_params[:custom_mailbox] &&
      cname_params[:custom_mailbox][:access_type].present? &&
      cname_params[:custom_mailbox][:access_type] == BOTH_ACCESS_TYPE
  end

  def outgoing_to_be_updated?
    @item.imap_mailbox.present? &&
      @item.smtp_mailbox.blank? &&
      (outgoing_access_type? || both_access_type?)
  end

  def incoming_to_be_updated?
    @item.smtp_mailbox.present? &&
      @item.imap_mailbox.blank? &&
      (incoming_access_type? || both_access_type?)
  end

  def invalid_incoming_update?
    @item.smtp_mailbox.blank? &&
      @item.imap_mailbox.blank? &&
      (incoming_access_type? || both_access_type?)
  end

  def invalid_outgoing_update?
    @item.imap_mailbox.blank? &&
      @item.smtp_mailbox.blank? &&
      (incoming_access_type? || both_access_type?)
  end

  def custom_to_freshdesk_mailbox_change?
    (@item.imap_mailbox.present? || @item.smtp_mailbox.present?) && cname_params[:mailbox_type] == FRESHDESK_MAILBOX
  end

  def imap_be_destroyed?
    custom_to_freshdesk_mailbox_change? || outgoing_access_type?
  end

  def smtp_be_destroyed?
    custom_to_freshdesk_mailbox_change? || incoming_access_type?
  end

  def valid_reference?
    private_api? && cname_params.try(:[], :custom_mailbox).try(:[], :reference_key)
  end

  def incoming_oauth?
    cname_params[:imap_mailbox_attributes][:authentication] == OAUTH if cname_params[:imap_mailbox_attributes].present?
  end

  def outgoing_oauth?
    cname_params[:smtp_mailbox_attributes][:authentication] == OAUTH if cname_params[:smtp_mailbox_attributes].present?
  end

  def oauth_reference
    cname_params[:custom_mailbox] && cname_params[:custom_mailbox][:reference_key]
  end

  def redis_obj
    @redis_obj ||= Email::Mailbox::OauthRedis.new(redis_key: oauth_reference)
  end

  def fetch_cached_auth_values
    cached_oauth_hash = redis_obj.fetch_hash
    [cached_oauth_hash[OAUTH_TOKEN], cached_oauth_hash[REFRESH_TOKEN]]
  end

  def remove_cached_oauth_value
    redis_obj.remove_hash
  end

  def custom_mailbox?
    @item.imap_mailbox.present? || @item.smtp_mailbox.present?
  end
end
