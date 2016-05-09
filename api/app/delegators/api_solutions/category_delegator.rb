module ApiSolutions
  class CategoryDelegator < BaseDelegator
    validate :portal_ids_exists?, if: -> { @portal_ids }

    def initialize(portal_ids)
      @portal_ids = portal_ids
      super
    end

    def portal_ids_exists?
      invalid_ids = @portal_ids - Account.current.portals.pluck(:id)
      if invalid_ids.any?
        errors[:visible_in] << :invalid_list
        @error_options = { visible_in: { list: "#{invalid_ids.join(', ')}" }  }
      end
    end
  end
end
