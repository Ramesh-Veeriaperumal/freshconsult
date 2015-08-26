class ApiSlaPolicyValidation < ApiValidation
  attr_accessor :applicable_to, :company_ids
  validates :applicable_to, data_type: { rules: Hash, allow_nil: false }, required: true
  validates :company_ids, data_type: { rules: Array, allow_nil: true }, array: { numericality: { allow_nil: false, message: 'Should have a valid number' } }

  def initialize(request_params, item)
    super(request_params, item)
    @company_ids = request_params[:applicable_to][:company_ids] if can_set_company_ids?(request_params)
  end

  private

    def can_set_company_ids?(request_params)
      request_params[:applicable_to].is_a?(Hash) && request_params[:applicable_to].key?(:company_ids)
    end
end
