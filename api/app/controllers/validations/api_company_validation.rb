class ApiCompanyValidation < ApiValidation
  attr_accessor :name, :description, :domains, :note, :custom_fields
  validates :name, required: true
  validates :custom_fields, data_type: { rules: Hash }, allow_nil: true
  validates :name, :description, :note, data_type: { rules: String, allow_nil: true }
  validates :domains, data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: String, allow_nil: true } }
end
