class PortalValidation < ApiValidation
  attr_accessor :preferences, :helpdesk, :primary_background, :nav_background, :portal_id, :helpdesk_logo, :id

  validates :preferences, data_type: { required: true, rules: Hash }, on: :update
  validates :primary_background, :nav_background, data_type: { rules: String }, custom_format: { with: ApiConstants::COLOR_CODE_VALIDATOR, accepted: :'valid color code' }, on: :update
  validates :helpdesk_logo, data_type: { rules: Hash, allow_nil: true }, on: :update
end
