class AuthenticationValidation < ApiValidation
  include Channel::V2::Iam::AuthenticationConstants

  attr_accessor :grant_type, :user_id, :client_id, :client_secret, :scope, :account_id, :account_domain

  validates :grant_type, required: true
  validates :grant_type, inclusion: { in: ALLOWED_GRANT_TYPES, message: format(ErrorConstants::ERROR_MESSAGES[:invalid_field_values], attribute: :grant_type) }, if: -> { grant_type.present? }
  validates :user_id, required: true
  validates :client_id, required: true
  validates :client_id, inclusion: { in: Iam::IAM_CLIENT_SECRETS.keys, message: format(ErrorConstants::ERROR_MESSAGES[:invalid_field_values], attribute: :client_id) }, if: -> { client_id.present? }
  validates :client_secret, data_type: { rules: String }, required: true
  validate :validate_scope, _merge_attributes: :scope, if: -> { errors.blank? && scope.present? }
  validate :validate_account_id, _merge_attributes: :scope, if: -> { errors.blank? && account_id.present? }
  validate :validate_account_domain, _merge_attributes: :scope, if: -> { errors.blank? && account_domain.present? }

  def validate_scope
    errors.add(:scope, format(ErrorConstants::ERROR_MESSAGES[:invalid_field_values], attribute: :scope)) unless (scope - PRIVILEGES_BY_NAME).empty?
  end

  def validate_account_id
    errors.add(:account_id, format(ErrorConstants::ERROR_MESSAGES[:invalid_field_values], attribute: :account_id)) unless Account.current.id.eql?(account_id.to_i)
  end

  def validate_account_domain
    errors.add(:account_domain, format(ErrorConstants::ERROR_MESSAGES[:invalid_field_values], attribute: :account_domain)) unless Account.current.full_domain.eql?(account_domain)
  end
end
