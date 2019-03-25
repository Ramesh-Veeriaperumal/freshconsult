class ApiSolutions::HomeValidation < ApiValidation
  attr_accessor :portal_id

  validates :portal_id, data_type: { rules: String, required: true, allow_nil: false }, if: :portal_id_dependant_actions?

  private

    def portal_id_dependant_actions?
      Solutions::HomeConstants::PORTAL_ID_DEPENDANT_ACTIONS.include?(validation_context)
    end
end
