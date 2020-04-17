module ApiSolutions
  class FolderBulkUpdateDelegator < BaseDelegator
    attr_accessor :company_ids, :category_id
    validate :validate_company_ids, if: -> { @company_ids }
    validate :validate_contact_segment_ids, if: -> { @contact_segment_ids }
    validate :validate_company_segment_ids, if: -> { @company_segment_ids }
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

    def validate_contact_segment_ids
      if Account.current.contact_filters.where(id: @contact_segment_ids).pluck(:id).empty?
        (error_options[:properties] ||= {}).merge!(nested_field: :contact_segment_ids, code: :invalid_contact_segment_ids)
        errors[:properties] = :invalid_contact_segment_ids
      end
    end

    def validate_company_segment_ids
      if Account.current.company_filters.where(id: @company_segment_ids).pluck(:id).empty?
        (error_options[:properties] ||= {}).merge!(nested_field: :company_segment_ids, code: :invalid_company_segment_ids)
        errors[:properties] = :invalid_company_segment_ids
      end
    end
  end
end
