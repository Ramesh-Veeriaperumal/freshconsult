module ApiSolutions
  class FolderBulkUpdateDelegator < BaseDelegator
    attr_accessor :company_ids, :category_id
    validate :validate_company_ids, if: -> { @company_ids }
    validate :category_exists?, if: -> { @category_id }

    def initialize(options)
      options.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
      super(options)
    end

    def category_exists?
      if Account.current.solution_category_meta.where(id: @category_id).empty?
        (error_options[:properties] ||= {}).merge!(nested_field: :category_id, code: :invalid_category_id)
        errors[:properties] = :invalid_category_id
      end
    end

    def validate_company_ids
      if Account.current.companies.where(id: @company_ids).pluck(:id).empty?
        (error_options[:properties] ||= {}).merge!(nested_field: :company_ids, code: :invalid_company_ids)
        errors[:properties] = :invalid_company_ids
      end
    end
  end
end
