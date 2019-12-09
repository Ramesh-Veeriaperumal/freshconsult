# Decorator Class for Email Config
class Email::MailboxDecorator < ApiDecorator
  delegate :id, :name, :product_id, :to_email, :reply_email, :group_id, :primary_role,
           :active, :imap_mailbox, :smtp_mailbox, :created_at, :updated_at, to: :record

  include Email::Mailbox::Constants

  ATTRIBUTE_NAMES = [:id, :name, :support_email, :group_id, :default_reply_email, :active,
                    :mailbox_type, :created_at, :updated_at].freeze

  def attributes
    selected_attributes = []
    selected_attributes << :product_id if Account.current.multi_product_enabled?
    selected_attributes << :custom_mailbox unless freshdesk_mailbox?
    selected_attributes | ATTRIBUTE_NAMES
  end

  def support_email
    reply_email
  end

  def default_reply_email
    primary_role
  end

  def mailbox_type
    (imap_mailbox.present? || smtp_mailbox.present?) ? CUSTOM_MAILBOX : FRESHDESK_MAILBOX
  end

  def custom_mailbox
    custom_mailbox_hash
  end

  def access_type
    type = if imap_mailbox.present? && smtp_mailbox.present?
             BOTH_ACCESS_TYPE
           elsif imap_mailbox.present?
             INCOMING_ACCESS_TYPE
           else
             OUTGOING_ACCESS_TYPE
           end
  end

  def to_hash
    result_hash = core_hash
    if freshdesk_mailbox?
      result_hash[:freshdesk_mailbox] = freshdesk_mailbox_hash
    else
      result_hash[:custom_mailbox] = custom_mailbox_api_response_hash
    end
    result_hash
  end

  private

    def core_hash
      result_hash = {
        id: id,
        name: name,
        support_email: reply_email,
        group_id: group_id,
        default_reply_email: primary_role,
        active: active,
        mailbox_type: (imap_mailbox.present? || smtp_mailbox.present?) ? CUSTOM_MAILBOX : FRESHDESK_MAILBOX,
        created_at: created_at.try(:utc),
        updated_at: updated_at.try(:utc)
      }
      result_hash[:product_id] = product_id if Account.current.multi_product_enabled?
      result_hash
    end

    def freshdesk_mailbox?
      !custom_mailbox?
    end

    def custom_mailbox?
      imap_mailbox.present? || smtp_mailbox.present?
    end

    def freshdesk_mailbox_hash
      { forward_email: to_email }
    end

    def custom_mailbox_hash
      result_hash = { access_type: access_type }
      result_hash[:incoming] = imap_mailbox_hash if imap_mailbox.present?
      result_hash[:outgoing] = smtp_mailbox_hash if smtp_mailbox.present?
      result_hash
    end

    def custom_mailbox_api_response_hash
      result_hash = { access_type: access_type }
      result_hash[:incoming] = imap_mailbox_hash.except(:password) if imap_mailbox.present?
      result_hash[:outgoing] = smtp_mailbox_hash.except(:password) if smtp_mailbox.present?
      result_hash
    end

    def imap_mailbox_hash
      result_hash = {}
      if imap_mailbox.present?
        result_hash.merge!(
          mail_server: imap_mailbox.server_name,
          port: imap_mailbox.port,
          use_ssl: imap_mailbox.use_ssl,
          delete_from_server: imap_mailbox.delete_from_server,
          authentication: imap_mailbox.authentication == IMAP_CRAM_MD5 ? CRAM_MD5 : imap_mailbox.authentication,
          user_name: imap_mailbox.user_name,
          password: imap_mailbox.password,
          failure_code: imap_failure_code
        )
      end
      result_hash
    end

    def smtp_mailbox_hash
      result_hash = {}
      if smtp_mailbox.present?
        result_hash.merge!(
          mail_server: smtp_mailbox.server_name,
          port: smtp_mailbox.port,
          use_ssl: smtp_mailbox.use_ssl,
          authentication: smtp_mailbox.authentication,
          user_name: smtp_mailbox.user_name,
          password: smtp_mailbox.password,
          failure_code: smtp_failure_code
        )
      end
      result_hash
    end

    def imap_failure_code
      Admin::EmailConfig::Imap::ErrorMapper.new(error_type: imap_mailbox.error_type).fetch_error_mapping if imap_mailbox.error_type.present?
    end

    def smtp_failure_code
      Admin::EmailConfig::Smtp::ErrorMapper.new(error_type: smtp_mailbox.error_type).fetch_error_mapping if smtp_mailbox.error_type.present?
    end
end
