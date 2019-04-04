class ApiSolutions::DraftValidation < ApiValidation
  attr_accessor :title, :description, :timestamp, :portal_id, :user_id, :modified_at, :last_updated_at

  validates :title, data_type: { rules: String, required: true }, if: :autosave_or_update?
  validates :description, data_type: { rules: String, required: true }, if: :autosave_or_update?
  validates :timestamp, data_type: { rules: Integer }, on: :autosave
  validates :portal_id, data_type: { rules: String, required: true, allow_nil: false }, on: :index
  validates :user_id, data_type: { rules: Integer }, on: :update
  validates :modified_at, data_type: { rules: Integer, required: true }, on: :update
  validates :last_updated_at, data_type: { rules: Integer, required: true }, on: :update

  AUTOSAVE_AND_UPDATE_ACTIONS = %i[autosave update].freeze

  private

    def autosave_or_update?
      AUTOSAVE_AND_UPDATE_ACTIONS.include?(validation_context)
    end
end
