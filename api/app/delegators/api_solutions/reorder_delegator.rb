module ApiSolutions
  class ReorderDelegator < BaseDelegator
    include SolutionConcern
    validate :validate_portal_id

    def initialize(record, options)
      options.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
      super(record, options)
    end
  end
end
