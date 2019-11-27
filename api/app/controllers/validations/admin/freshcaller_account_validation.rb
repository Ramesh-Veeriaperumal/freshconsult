class Admin::FreshcallerAccountValidation < ApiValidation
  attr_accessor :email, :password, :url

  validates :url, data_type: { rules: String, required: true }
  validates :email, data_type: { rules: String, required: true }, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :password, data_type: { rules: String, required: true }
end
