class ApiSolutions::CategoryValidation < ApiValidation
  attr_accessor :name, :description, :visible_in
  validates :name, data_type: { rules: String, required: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :description, data_type: { rules: String, allow_nil: true }

  validates :visible_in, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true } }
  validate :visible_in_has_valid_portal_ids?, if: -> { visible_in }

  def visible_in_has_valid_portal_ids?
    unless Account.current.portals.count > 1
      errors[:visible_in] << :multiple_portals_required
    end
  end

  def attributes_to_be_stripped
    SolutionConstants::CATEGORY_ATTRIBUTES_TO_BE_STRIPPED
  end
end
