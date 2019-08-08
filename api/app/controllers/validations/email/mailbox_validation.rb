class Email::MailboxValidation < ApiValidation
  include Email::Mailbox::Constants

  MANDATORY_FIELD_ARRAY = %i[name support_email mailbox_type].freeze

  attr_accessor :name, :support_email, :default_reply_email, :mailbox_type, :custom_mailbox,
                :group_id, :product_id, :incoming, :outgoing

  validates :name, data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :support_email, required: true, data_type: { rules: String }, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :mailbox_type, required: true, custom_inclusion: { in: MAILBOX_TYPES }
  validate :custom_mailbox_feature_check, if: :custom_mailbox?

  validates :group_id, custom_numericality: { only_integer: true, greater_than: 0 }
  validate :product_feature, if: -> { product_id }
  validates :product_id, custom_numericality: { only_integer: true, greater_than: 0 }
  validates :default_reply_email, data_type: { rules: 'Boolean', ignore_string: :allow_string_param }

  validate :custom_mailbox_absence, unless: :custom_mailbox?
  validates :custom_mailbox, required: true, if: -> { errors[:custom_mailbox].blank? && custom_mailbox? }
  validates :custom_mailbox,
            data_type: { rules: Hash },
            allow_nil: true,
            hash: {
              access_type: { custom_inclusion: { in: ACCESS_TYPES, required: true } },
              incoming: { data_type: { rules: Hash } },
              outgoing: { data_type: { rules: Hash } }
            }, if: -> { errors[:custom_mailbox].blank? }

  validates :incoming,
            required: true,
            data_type: { rules: Hash },
            hash: {
              mail_server: { data_type: { rules: String, required: true } },
              port: { custom_numericality: { only_integer: true, greater_than: 0, required: true } },
              use_ssl: { data_type: { rules: 'Boolean' } },
              delete_from_server: { data_type: { rules: 'Boolean' } },
              authentication: { custom_inclusion: { in: IMAP_AUTHENTICATION_TYPES, required: true } }, # TODO
              user_name: { data_type: { rules: String, required: true } },
              password: { data_type: { rules: String, required: true } }
            }, if: :incoming_required?

  validates :outgoing,
            required: true,
            data_type: { rules: Hash },
            hash: {
              mail_server: { data_type: { rules: String, required: true } },
              port: { custom_numericality: { only_integer: true, greater_than: 0, required: true } },
              use_ssl: { data_type: { rules: 'Boolean' } },
              authentication: { custom_inclusion: { in: SMTP_AUTHENTICATION_TYPES, required: true } },
              user_name: { data_type: { rules: String, required: true } },
              password: { data_type: { rules: String, required: true } }
            }, if: :outgoing_required?

  validate :incoming_absence, if: -> { errors[:custom_mailbox].blank? && custom_mailbox.present? && custom_mailbox[:access_type] == OUTGOING_ACCESS_TYPE }
  validate :outgoing_absence, if: -> { errors[:custom_mailbox].blank? && custom_mailbox.present? && custom_mailbox[:access_type] == INCOMING_ACCESS_TYPE }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end

  def product_feature
    unless Account.current.multi_product_enabled?
      errors[:product_id] = :require_feature_for_attribute
      error_options[:product_id] = {
        attribute: 'product_id',
        feature: :multi_product
      }
    end
  end

  def custom_mailbox_feature_check
    unless Account.current.has_features?(:mailbox)
      errors[:custom_mailbox] = :require_feature_for_attribute
      error_options[:custom_mailbox] = {
        attribute: 'custom_mailbox',
        feature: :mailbox
      }
    end
  end

  def custom_mailbox_absence
    errors[:custom_mailbox] = :invalid_field if custom_mailbox.present?
  end

  def incoming_absence
    errors[:incoming] = :invalid_field if incoming.present?
  end

  def outgoing_absence
    errors[:outgoing] = :invalid_field if outgoing.present?
  end

  def incoming_required?
    custom_mailbox? &&
      errors[:custom_mailbox].blank? &&
      custom_mailbox.present? &&
      [INCOMING_ACCESS_TYPE, BOTH_ACCESS_TYPE].include?(custom_mailbox[:access_type])
  end

  def outgoing_required?
    custom_mailbox? &&
      errors[:custom_mailbox].blank? &&
      custom_mailbox.present? &&
      [OUTGOING_ACCESS_TYPE, BOTH_ACCESS_TYPE].include?(custom_mailbox[:access_type])
  end

  def custom_mailbox?
    mailbox_type == CUSTOM_MAILBOX
  end
end
