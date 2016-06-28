module ApiSolutions
  class FolderDelegator < BaseDelegator
    validate :company_ids_exist?, if: -> { @company_ids }

    def initialize(params)
      @company_ids = params[:customer_folders_attributes]
      super(params)
    end

    def company_ids_exist?
      invalid_ids = @company_ids - Account.current.companies.pluck(:id)
      if invalid_ids.any?
        errors[:company_ids] << :invalid_list
        @error_options = { company_ids: { list: "#{invalid_ids.join(', ')}" }  }
      end
    end
  end
end
