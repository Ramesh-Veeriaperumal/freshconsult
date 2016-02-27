class ApiSlaPolicyValidation < ApiValidation
  attr_accessor :applicable_to, :company_ids

  validates :applicable_to, data_type: { required: true, rules: Hash }
  validates :company_ids, data_type: { rules: Array, required: true },
                          array: { custom_numericality: { only_integer: true, greater_than: 0, custom_message: :invalid_integer } }, if: -> { errors[:applicable_to].blank? }

  def initialize(request_params, item)
    super(request_params, item)
    @company_ids = applicable_to[:company_ids] if Hash === applicable_to
  end
end
