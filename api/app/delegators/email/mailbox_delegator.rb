class Email::MailboxDelegator < BaseDelegator
  include MailboxValidator
  include Email::Mailbox::Constants

  validate :imap_mailbox, if: -> { @record.imap_mailbox.present? && @record.imap_mailbox.changed? }
  validate :smtp_mailbox, if: -> { @record.smtp_mailbox.present? && @record.smtp_mailbox.changed? }
  validate :group_presence, if: -> { group_id && attr_changed?('group_id') }
  validate :product_presence, if: -> { product_id && attr_changed?('product_id') }
  validate :changes_to_default_primary_role, unless: -> { primary_role && attr_changed?('primary_role') }
  validate :changes_to_product_id_on_default_mailbox, if: -> { attr_changed?('product_id') }

  def initialize(record, options = {})
    @record = record
    super(record, options)
    @primary_role = options[:primary_role]
  end

  def imap_mailbox
    verified_result = verify_imap_mailbox(@record.imap_mailbox)
    errors[:incoming] = verified_result[:msg] unless verified_result[:success]
  end

  def smtp_mailbox
    verified_result = verify_smtp_mailbox(@record.smtp_mailbox)
    unless verified_result[:success]
      errors[:outgoing] = verified_result[:msg]
      error_options[:outgoing] = verified_result[:options] if verified_result[:options].present?
    end
  end

  def product_presence
    product = Account.current.products_ar_cache.detect { |x| product_id == x.id }
    if product.nil?
      errors[:product_id] << :"can't be blank"
    else
      self.product = product
    end
  end

  def group_presence # this is a custom validate method so that group cache can be used.
    group = Account.current.support_agent_groups_from_cache.detect { |x| group_id == x.id }
    if group.nil?
      errors[:group_id] << :"can't be blank"
    else
      self.group = group
    end
  end

  def changes_to_default_primary_role
    errors[:default_reply_email] << :default_primary_role_changed if primary_role_was == true && primary_role == false
  end

  def changes_to_product_id_on_default_mailbox
    errors[:product_id] << :default_mailbox_product_changed if primary_role_was == true
  end

  private

    def incoming_oauth?
      @record.imap_mailbox.authentication == OAUTH
    end

    def outgoing_oauth?
      @record.smtp_mailbox.authentication == OAUTH
    end
end
