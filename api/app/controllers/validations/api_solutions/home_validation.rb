class ApiSolutions::HomeValidation < ApiValidation
  attr_accessor :portal_id

  validates :portal_id, allow_nil: false, data_type: { rules: String }
  validates :portal_id, required: true, if: -> { validation_context == :summary }
end
