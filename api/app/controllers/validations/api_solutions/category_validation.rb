class ApiSolutions::CategoryValidation < ApiValidation
	CHECK_PARAMS_SET_FIELDS = %w(visible_in).freeze
  attr_accessor :name, :description, :visible_in
  validates :name, data_type: { rules: String, required: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :description, data_type: { rules: String, allow_nil: true }

  validates :visible_in, custom_absence: { message: :multiple_portals_required }, unless: -> { Account.current.has_multiple_portals? }
  validates :visible_in, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true } }

  def attributes_to_be_stripped
    SolutionConstants::CATEGORY_ATTRIBUTES_TO_BE_STRIPPED
  end
end
