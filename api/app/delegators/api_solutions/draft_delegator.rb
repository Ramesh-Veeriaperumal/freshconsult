module ApiSolutions
  class DraftDelegator < BaseDelegator
    include SolutionConcern

    validate :validate_portal_id, if: -> { @portal_id }
    validate :validate_author, on: :update

    def initialize(record, options = {})
      @item = record
      options.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
      super(record, options)
    end

    def validate_author
      author = Account.current.technicians.where(id: @user_id).first
      errors[:user_id] << :invalid_draft_author unless author && author.privilege?(:publish_solution)
    end
  end
end
