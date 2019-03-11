module ApiSolutions
  class HomeDelegator < BaseDelegator
    include SolutionConcern
    validate :validate_portal_id, if: :portal_id_dependant_actions?

    def initialize(record, options = {})
      options.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
      super(record, options)
    end

    private

      def portal_id_dependant_actions?
        Solutions::HomeConstants::PORTAL_ID_DEPENDANT_ACTIONS.include?(validation_context)
      end
  end
end
