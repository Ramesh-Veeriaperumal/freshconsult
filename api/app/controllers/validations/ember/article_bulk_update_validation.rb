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
    if properties.blank?
      errors[:properties] << :select_a_field
    elsif !Account.current.adv_article_bulk_actions_enabled?
      advanced_article_bulk_action_error(:agent_id) if properties[:agent_id]
      advanced_article_bulk_action_error(:tags) if properties[:tags]
    end
    errors.blank?
  end

  def advanced_article_bulk_action_error(field)
    errors[:"properties[:#{field}]"] << :require_feature
    error_options[:"properties[:#{field}]"] = { feature: :adv_article_bulk_actions, code: :access_denied }
  end
end
