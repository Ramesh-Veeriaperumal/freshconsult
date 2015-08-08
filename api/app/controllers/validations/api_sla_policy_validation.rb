class ApiSlaPolicyValidation < ApiValidation
  attr_accessor :conditions, :company_ids
  validates :conditions, data_type: { rules: Hash }, required: true
  validates :company_ids, data_type: { rules: Array, allow_nil: true }, array: { numericality: { allow_nil: true } }

  def initialize(request_params, item)
    super(request_params, item)
    @company_ids = request_params[:conditions][:company_ids]
  end
end
