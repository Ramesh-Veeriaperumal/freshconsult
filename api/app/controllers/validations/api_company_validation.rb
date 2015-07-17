class ApiCompanyValidation < ApiValidation
  attr_accessor :name, :description, :domains, :note, :sla_policy_id, :custom_fields
  validates :name, required: true
  validates :custom_fields, data_type: { rules: Hash }, allow_nil: true
  validates :name, :description, :domains, :note, data_type: { rules: String, allow_nil: true }
end
