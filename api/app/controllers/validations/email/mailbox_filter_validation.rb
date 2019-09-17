class Email::MailboxFilterValidation < FilterValidation

  attr_accessor :order_by, :order_type, :product_id, :conditions, :group_id, :support_email, :forward_email, :active

  validates :order_by, custom_inclusion: { in: EmailMailboxConstants::ORDER_BY }
  validates :order_by, required: true, if: -> { order_type.present? }
  validates :order_type, custom_inclusion: { in: EmailMailboxConstants::ORDER_TYPE }
  validates :product_id, :group_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }
  validates :forward_email, data_type: { rules: String }, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :support_email, data_type: { rules: String }
  validate :support_email_length, if: -> { support_email && errors[:support_email].blank? }
  validates :support_email, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' }, unless: -> { private_api? }
  validates :active, data_type: { rules: String }, custom_inclusion: { in: %w[true false] }

  private

    def support_email_length
      if support_email.delete('*').length < EmailMailboxConstants::MIN_CHAR_FOR_SEARCH || support_email.delete('*').length > ApiConstants::MAX_LENGTH_STRING
        errors[:support_email] = :too_long_too_short
        error_options.merge!(support_email: { current_count: support_email.delete('*').length, element_type: 'characters', max_count: ApiConstants::MAX_LENGTH_STRING, min_count: EmailMailboxConstants::MIN_CHAR_FOR_SEARCH })
      end
    end
end
