class ApiSlaPolicyValidation < ApiValidation
  attr_accessor :applicable_to, :company_ids

  validates :applicable_to, data_type: { required: true, rules: Hash }
  validates :company_ids, data_type: { rules: Array, required: true },
                          array: { custom_numericality: { only_integer: true, greater_than: 0 } }, if: -> { errors[:applicable_to].blank? }

  def initialize(request_params, item)
    super(request_params, item)
    @company_ids = applicable_to[:company_ids] if can_set_company_ids?
  end

  def can_set_company_ids?
  	applicable_to.is_a?(Hash) && applicable_to.key?(:company_ids)
  end
end
