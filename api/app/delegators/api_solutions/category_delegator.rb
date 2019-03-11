module ApiSolutions
  class CategoryDelegator < BaseDelegator
    include SolutionConcern

    validate :validate_portal_id, if: -> { @portal_id }
    validate :validate_visible_in_portals, if: -> { @visible_in_portals }

    def initialize(record, options = {})
      options.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
      super(record, options)
    end

    def validate_visible_in_portals
      invalid_portal_ids = @visible_in_portals - Account.current.portals.where(id: @visible_in_portals).pluck(:id)
      if invalid_portal_ids.present?
        errors[:visible_in_portals] << :invalid_list
        @error_options = { visible_in_portals: { list: invalid_portal_ids.join(', ').to_s } }
      end
    end
  end
end
