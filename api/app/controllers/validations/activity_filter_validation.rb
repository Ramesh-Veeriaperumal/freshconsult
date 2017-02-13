class ActivityFilterValidation < ApiValidation
  attr_accessor :limit, :since_id, :before_id
  validates :limit, :since_id, :before_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }
end
