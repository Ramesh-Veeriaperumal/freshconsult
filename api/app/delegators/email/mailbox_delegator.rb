class Email::MailboxDelegator < BaseDelegator
  include MailboxValidator
  
  validate :imap_mailbox, if: -> { @imap_mailbox_attributes.present? }
  validate :smtp_mailbox, if: -> { @smtp_mailbox_attributes.present? }
  validate :group_presence, if: -> { group_id && attr_changed?('group_id') }
  validate :product_presence, if: -> { product_id && attr_changed?('product_id') }

  def initialize(record, options = {})
    super(record, options)
    @imap_mailbox_attributes = options[:imap_mailbox_attributes]
    @smtp_mailbox_attributes = options[:smtp_mailbox_attributes]
  end
  
  def imap_mailbox
    verified_result = verify_imap_mailbox(@imap_mailbox_attributes)
    errors[:incoming] = verified_result[:msg] unless verified_result[:success]
  end

  def smtp_mailbox
    verified_result = verify_smtp_mailbox(@smtp_mailbox_attributes)
    unless verified_result[:success]
      errors[:outgoing] = verified_result[:msg]
      error_options[:outgoing] = verified_result[:options] if verified_result[:options].present?
    end
  end
  
  def product_presence
    product = Account.current.products_from_cache.detect { |x| product_id == x.id }
    if product.nil?
      errors[:product_id] << :"can't be blank"
    else
      self.product = product
    end
  end

  def group_presence # this is a custom validate method so that group cache can be used.
    group = Account.current.groups_from_cache.detect { |x| group_id == x.id }
    if group.nil?
      errors[:group_id] << :"can't be blank"
    else
      self.group = group
    end
  end
end