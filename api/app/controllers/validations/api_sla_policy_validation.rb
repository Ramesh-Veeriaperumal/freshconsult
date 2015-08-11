class ApiSlaPolicyValidation < ApiValidation
  attr_accessor :applicable_to, :company_ids
  validates :applicable_to, data_type: { rules: Hash }, required: true
  validates :company_ids, data_type: { rules: Array, allow_nil: true }, array: { numericality: { allow_nil: true } }

  def initialize(request_params, item)
    super(request_params, item)
    @company_ids = request_params[:applicable_to][:company_ids]
  end
end
