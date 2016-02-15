class ApiSlaPolicyValidation < ApiValidation
  attr_accessor :applicable_to, :company_ids

  # validate for data_type if value is part of request
  validates :applicable_to, data_type: { rules: Hash }, if: -> { applicable_to }
  # validate for requiredness if value is nil
  validates :applicable_to, data_type: { rules: Hash, required: true }, unless: -> { applicable_to }
  # validate for data_type if value is part of request
  validates :company_ids, data_type: { rules: Array }, if: :can_set_company_ids?
  # validate for requiredness if value is not part of request.
  validates :company_ids, data_type: { rules: Array, required: true }, if: -> { errors[:applicable_to].blank? && !company_ids }
  validates :company_ids, array: { custom_numericality: { only_integer: true, greater_than: 0, message: :invalid_integer } }

  def initialize(request_params, item)
    super(request_params, item)
    @company_ids = applicable_to[:company_ids] if can_set_company_ids?
  end

  private

    def can_set_company_ids?
      applicable_to.is_a?(Hash) && applicable_to.key?(:company_ids)
    end
end
