class Email::MailboxValidation < ApiValidation
  include Email::Mailbox::Constants

  MANDATORY_FIELD_ARRAY = %i[name support_email mailbox_type].freeze

  attr_accessor :name, :support_email, :default_reply_email, :mailbox_type, :custom_mailbox,
                :group_id, :product_id, :incoming, :outgoing, :reference_key

  validates :name, data_type: { rules: String, allow_nil: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :support_email,
            required: true,
            data_type: { rules: String },
            custom_format: {
              with: ApiConstants::EMAIL_VALIDATOR,
              accepted: :'valid email address'
            },
            custom_length: {
              maximum: ApiConstants::MAX_LENGTH_STRING
            }
  validates :mailbox_type, required: true, custom_inclusion: { in: MAILBOX_TYPES }
  validate :custom_mailbox_feature_check, if: :custom_mailbox?
  validates :group_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validate :product_feature, if: -> { product_id }
  validates :product_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :default_reply_email, data_type: { rules: 'Boolean', ignore_string: :allow_string_param }

  validate :custom_mailbox_absence, unless: :custom_mailbox?
  validates :custom_mailbox, required: true, if: -> { errors[:custom_mailbox].blank? && custom_mailbox? }
  validates :custom_mailbox,
            data_type: { rules: Hash },
            allow_nil: true,
            hash: {
              access_type: { custom_inclusion: { in: ACCESS_TYPES, required: true } },
              reference_key: { data_type: { rules: String } },
              incoming: { data_type: { rules: Hash } },
              outgoing: { data_type: { rules: Hash } }
            }, if: -> { errors[:custom_mailbox].blank? }

  validates :reference_key,
            required: true,
            if: :reference_key_required?

  validates :incoming,
            required: true,
            data_type: { rules: Hash },
            hash: {
              mail_server: { data_type: { rules: String, required: true } },
              port: { custom_numericality: { only_integer: true, greater_than: 0, required: true } },
              use_ssl: { data_type: { rules: 'Boolean', required: true } },
              delete_from_server: { data_type: { rules: 'Boolean', required: true } },
              authentication: { data_type: { rules: String, required: true } },
              user_name: { data_type: { rules: String, required: true, presence: true } },
              password: { data_type: { rules: String, allow_blank: true, allow_nil: true } }
            }, if: :incoming_required?

  validates :outgoing,
            required: true,
            data_type: { rules: Hash },
            hash: {
              mail_server: { data_type: { rules: String, required: true } },
              port: { custom_numericality: { only_integer: true, greater_than: 0, required: true } },
              use_ssl: { data_type: { rules: 'Boolean', required: true } },
              authentication: { data_type: { rules: String, required: true } },
              user_name: { data_type: { rules: String, required: true, presence: true } },
              password: { data_type: { rules: String, allow_blank: true, allow_nil: true } }
            }, if: :outgoing_required?

  validate :incoming_absence, if: -> { errors[:custom_mailbox].blank? && outgoing_access_type? }
  validate :outgoing_absence, if: -> { errors[:custom_mailbox].blank? && incoming_access_type? }

  validate :validate_reference, if: -> { errors[:custom_mailbox].blank? && oauth? && oauth_reference }
  validate :validate_oauth_email, if: -> { errors[:custom_mailbox].blank? && oauth? && oauth_reference }
  validate :invalid_reference_presence, if: -> { errors[:custom_mailbox].blank? }
  validate :incoming_password_presence, if: -> { errors[:custom_mailbox].blank? && (incoming_access_type? || both_access_type?) && errors[:incoming].blank? && !incoming_oauth? }
  validate :outgoing_password_presence, if: -> { errors[:custom_mailbox].blank? && (outgoing_access_type? || both_access_type?) && errors[:outgoing].blank? && !outgoing_oauth? }

  validate :incoming_authentication_type, if: -> { errors[:custom_mailbox].blank? && (incoming_access_type? || both_access_type?) && errors[:incoming].blank? }
  validate :outgoing_authentication_type, if: -> { errors[:custom_mailbox].blank? && (outgoing_access_type? || both_access_type?) && errors[:outgoing].blank? }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param, item_decorator_class)
    @item = item
    @decorated_item = item_decorator_class.new(@item) if @item
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
    errors[:custom_mailbox] = :invalid_field if !custom_mailbox_marked_for_destruction? && custom_mailbox.present?
  end

  def incoming_absence
    errors[:incoming] = :invalid_field if !incoming_marked_for_destruction? && incoming.present?
  end

  def outgoing_absence
    errors[:outgoing] = :invalid_field if !outgoing_marked_for_destruction? && outgoing.present?
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

  def reference_key_required?
    custom_mailbox? &&
      errors[:custom_mailbox].blank? &&
      custom_mailbox.present? &&
      private_api? && create? && incoming_or_outgoing_oauth?
  end

  def custom_mailbox?
    mailbox_type == CUSTOM_MAILBOX
  end

  def outgoing_access_type?
    custom_mailbox? &&
      custom_mailbox.present? &&
      custom_mailbox[:access_type] == OUTGOING_ACCESS_TYPE
  end

  def incoming_access_type?
    custom_mailbox? &&
      custom_mailbox.present? &&
      custom_mailbox[:access_type] == INCOMING_ACCESS_TYPE
  end

  def both_access_type?
    custom_mailbox? &&
      custom_mailbox.present? &&
      custom_mailbox[:access_type] == BOTH_ACCESS_TYPE
  end

  def custom_mailbox_marked_for_destruction?
    custom_access_type = @decorated_item.try(:access_type)
    if custom_access_type == BOTH_ACCESS_TYPE
      incoming_marked_for_destruction? && outgoing_marked_for_destruction?
    elsif custom_access_type == OUTGOING_ACCESS_TYPE
      outgoing_marked_for_destruction?
    else
      incoming_marked_for_destruction?
    end
  end

  def incoming_marked_for_destruction?
    @item.try(:imap_mailbox).try(:marked_for_destruction?)
  end

  def outgoing_marked_for_destruction?
    @item.try(:smtp_mailbox).try(:marked_for_destruction?)
  end

  private

    def invalid_reference_presence
      errors[:reference_key] = :invalid_field if !oauth? && reference_key.present?
    end

    def item_decorator_class
      @item_decorator_class ||= EmailMailboxConstants::DECORATOR_CLASS.constantize
    end

    def oauth_reference
      custom_mailbox[:reference_key]
    end

    def oauth?
      custom_mailbox.present? && private_api? &&
        incoming_or_outgoing_oauth?
    end

    def incoming_or_outgoing_oauth?
      incoming_oauth? || outgoing_oauth?
    end

    def incoming_oauth?
      incoming && incoming[:authentication] == OAUTH
    end

    def outgoing_oauth?
      outgoing && outgoing[:authentication] == OAUTH
    end

    def validate_reference
      errors[:reference_key] = :invalid_oauth_reference unless redis_obj.exists?
    end

    def redis_obj
      @redis_obj ||= Email::Mailbox::OauthRedis.new(redis_key: oauth_reference)
    end

    def validate_oauth_email
      errors[:reference_key] = :invalid_oauth_reference if invalid_reference?
    end

    def invalid_reference?
      cached_oauth_hash = redis_obj.fetch_hash
      oauth_email = cached_oauth_hash[OAUTH_EMAIL]
      invalid_incoming_reference?(oauth_email) || invalid_outgoing_reference?(oauth_email)
    end

    def invalid_incoming_reference?(oauth_email)
      return if incoming_marked_for_destruction?

      incoming[:user_name] != oauth_email if incoming && incoming[:user_name]
    end

    def invalid_outgoing_reference?(oauth_email)
      return if outgoing_marked_for_destruction?

      outgoing[:user_name] != oauth_email if outgoing && outgoing[:user_name]
    end

    def incoming_password_presence
      return if incoming[:password].present?

      errors[:incoming] = :missing_field
      error_options[:incoming] = {
        nested_field: :password
      }
    end

    def outgoing_password_presence
      return if outgoing[:password].present?

      errors[:outgoing] = :missing_field
      error_options[:outgoing] = {
        nested_field: :password
      }
    end

    def incoming_authentication_type
      return if IMAP_AUTHENTICATION_TYPES.include?(incoming[:authentication]) || (private_api? && (IMAP_AUTHENTICATION_TYPES | [OAUTH]).include?(incoming[:authentication]))

      errors[:incoming] = :not_included
      error_options[:incoming] = {
        nested_field: :authentication,
        list: IMAP_AUTHENTICATION_TYPES.join(',')
      }
    end

    def outgoing_authentication_type
      return if SMTP_AUTHENTICATION_TYPES.include?(outgoing[:authentication]) || (private_api? && (SMTP_AUTHENTICATION_TYPES | [OAUTH]).include?(outgoing[:authentication]))

      errors[:outgoing] = :not_included
      error_options[:outgoing] = {
        nested_field: :authentication,
        list: SMTP_AUTHENTICATION_TYPES.join(',')
      }
    end
end
