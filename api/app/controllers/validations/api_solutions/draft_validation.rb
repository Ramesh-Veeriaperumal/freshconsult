class ApiSolutions::DraftValidation < ApiValidation
  attr_accessor :portal_id

  validates :portal_id, data_type: { rules: String, required: true, allow_nil: false }, on: :index
end
