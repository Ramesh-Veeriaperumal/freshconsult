class ApiSolutions::ReorderValidation < ApiValidation
  attr_accessor :position, :portal_id
  validates :position, custom_numericality: { only_integer: true, greater_than: 0, required: true, allow_nil: false }
  validates :portal_id, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
end
