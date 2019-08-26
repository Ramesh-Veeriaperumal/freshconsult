class Notifications::Email::BccValidation < ApiValidation
  attr_accessor :emails

  validates :emails, data_type: { rules: Array, required: true, allow_nil: true }, array: { data_type: { rules: String } }
end
