class ArticleBulkUpdateValidation < ApiValidation
  CHECK_PARAMS_SET_FIELDS = %w[properties].freeze
  attr_accessor :properties

  validates :properties, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.articles_bulk_validation } }, required: true

  validate :validate_properties

  validate :validate_status, if: -> { properties && properties[:status].present? }

  validate :validate_outdated_property, if: -> { properties && properties[:outdated].present? }

  validate :validate_approval_status, if: -> { properties && properties[:approval_status].present? }

  def articles_bulk_validation
    {
      folder_id: { data_type: { rules: Integer, allow_nil: false } },
      agent_id: { data_type: { rules: Integer, allow_nil: false } },
      tags: { data_type: { rules: Array, allow_nil: false } },
      outdated: { data_type: { rules: 'Boolean' } },
      status: { data_type: { rules: Integer, allow_nil: false } },
      approval_status: { data_type: { rules: Integer } },
      approver_id: { data_type: { rules: Integer } }
    }
  end

  def validate_status
    if properties[:status] != Solution::Constants::STATUS_KEYS_BY_TOKEN[:published]
      (error_options[:properties] ||= {}).merge!(nested_field: :status, code: :status_is_not_valid)
      errors[:properties] = :status_is_not_valid
    end
  end

  def validate_outdated_property
    if properties[:outdated] != false
      (error_options[:properties] ||= {}).merge!(nested_field: :outdated, code: :outdated_property_is_not_valid)
      errors[:properties] = :outdated_property_is_not_valid
    end
  end

  def validate_approval_status
    if article_approval_workflow_enabled?
      if properties.key?(:approval_status) && Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN.values.exclude?(properties[:approval_status])
        (error_options[:properties] ||= {}).merge!(nested_field: :approval_data, code: :approval_data_invalid)
        errors[:properties] = :approval_data_invalid
      end
    else
      errors[:properties] = :require_feature
      error_options[:properties] = { feature: :article_approval_workflow, code: :access_denied }
    end
  end

  def validate_properties
    if properties.blank?
      errors[:properties] << :select_a_field
    elsif !Account.current.adv_article_bulk_actions_enabled?
      advanced_article_bulk_action_error(:agent_id) if properties[:agent_id]
      advanced_article_bulk_action_error(:tags) if properties[:tags]
      advanced_article_bulk_action_error(:status) if properties[:status]
      advanced_article_bulk_action_error(:outdated) if properties.key?(:outdated)
      advanced_article_bulk_action_error(:approval_status) if properties[:approval_status]
    end
    errors.blank?
  end

  def advanced_article_bulk_action_error(field)
    errors[:"properties[:#{field}]"] << :require_feature
    error_options[:"properties[:#{field}]"] = { feature: :adv_article_bulk_actions, code: :access_denied }
  end

  private

    def article_approval_workflow_enabled?
      Account.current.article_approval_workflow_enabled?
    end
end
