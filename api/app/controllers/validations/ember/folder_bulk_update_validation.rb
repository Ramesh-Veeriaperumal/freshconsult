class FolderBulkUpdateValidation < ApiValidation
  CHECK_PARAMS_SET_FIELDS = %w[properties].freeze
  attr_accessor :properties

  validates :properties, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.folders_bulk_validation } }, required: true

  validate :validate_properties

  validate :validate_company_ids, if: -> { errors.blank? }

  def validate_properties
    errors[:properties] << :select_a_field if properties.blank?
    errors.blank?
  end

  def folders_bulk_validation
    {
      category_id: { data_type: { rules: Integer, allow_nil: false } },
      visibility: { custom_numericality: { only_integer: true, greater_than: 0 }, custom_inclusion: { in: Solution::Constants::VISIBILITY_NAMES_BY_KEY.keys } },
      company_ids: { data_type: { rules: Array, allow_nil: false } }
    }
  end

  def validate_company_ids
    if properties[:visibility] == Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:company_users] && properties[:company_ids].blank?
      (error_options[:properties] ||= {}).merge!(nested_field: :company_ids, code: :company_ids_not_present)
      errors[:properties] = :company_ids_not_present
    elsif properties[:company_ids].present? && properties[:visibility] != Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:company_users]
      (error_options[:properties] ||= {}).merge!(nested_field: :company_ids, code: :company_ids_not_allowed)
      errors[:properties] = :company_ids_not_allowed
    end
  end
end
