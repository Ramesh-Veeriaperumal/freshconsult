module Admin::AutomationRules::Performer
  class PerformerDelegator < BaseDelegator
    include Admin::AutomationDelegatorHelper
    include Admin::AutomationValidationHelper
    include Admin::AutomationConstants

    attr_accessor :type, :members

    validate :validate_members, if: -> { members.present? && type == 1 }

    def initialize(record, options = {})
      @members = options[:performer][:members]
      @type = options[:performer][:type]
      super(record)
    end

    def validate_members
      absent_in_db_error('performer[:member]', members, all_agents)
    end
  end
end