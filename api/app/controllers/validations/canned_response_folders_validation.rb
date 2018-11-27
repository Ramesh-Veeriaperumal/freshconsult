class CannedResponseFoldersValidation < ApiValidation
  attr_accessor :name, :request_params, :id
  validates :name, data_type: { rules: String }, presence: true, custom_length: { minimum: 3, maximum: 240, message: :too_long_too_short }
  validate :name_validation, if: -> { errors.blank? }

  def initialize(request_params, item = nil, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end

  # All account will have a default folder Personal_{account_id}, so we are not encouraging folder name starts with Personal_
  def name_validation
    name.start_with?('Personal_') ? errors[:name] << 'Name should not starts with Personal_' : true
  end
end
