class DraftDelegator < BaseDelegator
  include ParserUtil

  validate :validate_from_email, if: -> { @from_email.present? }

  def initialize(record, options = {})
    super(record, options)
    @from_email = options[:from_email]
  end

  def validate_from_email
    email_address = parse_email(@from_email)[:email]
    email_config = Account.current.email_configs.where(reply_email: email_address).first
    errors[:from_email] << :"can't be blank" unless email_config
  end
end
