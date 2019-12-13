class ApiSolutions::DraftValidation < ApiValidation
  attr_accessor :title, :description, :timestamp, :portal_id, :user_id, :modified_at, :last_updated_at, :approval_data

  validates :title, data_type: { rules: String, required: true }, if: :autosave_or_update?
  validates :description, data_type: { rules: String, required: true }, if: :autosave_or_update?
  validates :timestamp, data_type: { rules: Integer }, on: :autosave
  validates :portal_id, data_type: { rules: String, required: true, allow_nil: false }, on: :index
  validates :user_id, data_type: { rules: Integer }, on: :update
  validates :modified_at, data_type: { rules: Integer, required: true }, on: :update
  validates :last_updated_at, data_type: { rules: Integer, required: true }, on: :update
  validate :approval_info
  validates :approval_data, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.approval_validation } }, if: :article_approval_workflow_enabled?

  AUTOSAVE_AND_UPDATE_ACTIONS = %i[autosave update].freeze
  APPROVAL_DATA_FIELDS = [:approver_id, :approval_status, :user_id].freeze

  def approval_validation
    {
      approver_id: { data_type: { rules: Integer, allow_nil: false } },
      approval_status: { custom_numericality: { only_integer: true, greater_than: 0 }, custom_inclusion: { in: Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN.values }, required: true },
      user_id: { data_type: { rules: Integer, allow_nil: false } }
    }
  end

  def approval_info
    if article_approval_workflow_enabled?
      if @approval_data.present? && ((@approval_data.keys.map(&:to_sym) - APPROVAL_DATA_FIELDS).present? || @approval_data.length != APPROVAL_DATA_FIELDS.length)
        errors[:approval_data] << :approval_data_invalid
      end
    elsif @approval_data
      errors[:approval_data] << :approval_data_not_allowed
    end
  end

  private

    def autosave_or_update?
      AUTOSAVE_AND_UPDATE_ACTIONS.include?(validation_context)
    end

    def article_approval_workflow_enabled?
      Account.current.article_approval_workflow_enabled?
    end
end
