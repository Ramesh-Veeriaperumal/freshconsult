class Email::MailboxFilterValidation < FilterValidation
  attr_accessor :order_by, :order_type

  validates :order_by, custom_inclusion: { in: EmailMailboxConstants::ORDER_BY }
  validates :order_by, required: true, if: -> { order_type.present? }
  validates :order_type, custom_inclusion: { in: EmailMailboxConstants::ORDER_TYPE }
end
