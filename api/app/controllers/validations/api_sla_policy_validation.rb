class ApiSlaPolicyValidation < ApiValidation
  attr_accessor :applicable_to, :company_ids
  validates :applicable_to, data_type: { rules: Hash, required: true }
  validates :company_ids, data_type: { rules: Array, required: true }, if: -> { errors[:applicable_to].blank? }
  validates :company_ids, array: { custom_numericality: { message: 'invalid_integer' } }
 

  def initialize(request_params, item)
    super(request_params, item)
    @company_ids = applicable_to[:company_ids] if can_set_company_ids?(applicable_to)
  end

  private

    def can_set_company_ids?(applicable_to)
      applicable_to.is_a?(Hash) && applicable_to.key?(:company_ids)
    end
end
