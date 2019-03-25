class ArticleBulkUpdateValidation < ApiValidation
  CHECK_PARAMS_SET_FIELDS = %w[properties].freeze
  attr_accessor :properties

  validates :properties, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.articles_bulk_validation } }, required: true

  validate :validate_properties

  def articles_bulk_validation
    {
      folder_id: { data_type: { rules: Integer, allow_nil: false } },
      agent_id: { data_type: { rules: Integer, allow_nil: false } },
      tags: { data_type: { rules: Array, allow_nil: false } }
    }
  end

  def validate_properties
    errors[:properties] << :select_a_field if properties.blank?
    errors.blank?
  end
end
