module ApiSolutions
  class FolderDelegator < BaseDelegator
    attr_accessor :contact_folders_attributes, :company_folders_attributes, :customer_folders_attributes
    validate :validate_contact_filter_ids, if: -> { @contact_folders_attributes.present? }
    validate :validate_company_filter_ids, if: -> { @company_folders_attributes.present? }
    validate :validate_company_ids, if: -> { @customer_folders_attributes.present? }
    validate :validate_category_translation, on: :create, if: -> { @id && @language_code }

    def initialize(options)
      options.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
      super(options)
    end

    def validate_contact_filter_ids
      if Account.current.contact_filters.where(id: @contact_folders_attributes).size != @contact_folders_attributes.size
        (error_options[:properties] ||= {})[:code] = :invalid_contact_filter_ids
        errors[:contact_filter_ids] = :invalid_contact_filter_ids
      end
    end

    def validate_company_filter_ids
      if Account.current.company_filters.where(id: @company_folders_attributes).size != @company_folders_attributes.size
        (error_options[:properties] ||= {})[:code] = :invalid_company_filter_ids
        errors[:company_filter_ids] = :invalid_company_filter_ids
      end
    end

    def validate_company_ids
      if Account.current.customers.where(id: @customer_folders_attributes).size != @customer_folders_attributes.size
        (error_options[:properties] ||= {})[:code] = :invalid_company_ids
        errors[:company_ids] = :invalid_company_ids
      end
    end

    def validate_category_translation
      language = Language.find_by_code(@language_code)
      errors[:category_id] = :invalid_category_translation if Account.current.solution_folder_meta.find_by_id(@id).solution_category_meta.safe_send("#{language.to_key}_category").nil?
    end
  end
end
