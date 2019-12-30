class Admin::FreshcallerAccountValidation < ApiValidation
  attr_accessor :email, :password, :url, :agent_ids

  validates :url, data_type: { rules: String, required: true }, on: :link
  validates :email, data_type: { rules: String, required: true },
                    custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' },
                    custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }, on: :link
  validates :password, data_type: { rules: String, required: true }, on: :link
  validates :agent_ids, data_type: { rules: Array, required: true }, on: :update
end
