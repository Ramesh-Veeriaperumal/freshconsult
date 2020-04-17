module ApiSolutions
  class FolderDelegator < BaseDelegator
    attr_accessor :contact_folders_attributes, :company_folders_attributes, :customer_folders_attributes

    validate :validate_contact_segment_ids, if: -> { @contact_folders_attributes.present? }
    validate :validate_company_segment_ids, if: -> { @company_folders_attributes.present? }
    validate :validate_company_ids, if: -> { @customer_folders_attributes.present? }
    validate :validate_category_translation, on: :create, if: -> { @id && @language_code }

    def initialize(options)
      options.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
      super(options)
    end

    def validate_contact_segment_ids
      valid_contact_segment_ids = Account.current.contact_filters.where(id: @contact_folders_attributes).pluck(:id)
      if valid_contact_segment_ids.size != @contact_folders_attributes.size
        bad_contact_segment_ids = @contact_folders_attributes - valid_contact_segment_ids
        errors[:contact_segment_ids] << :invalid_list if bad_contact_segment_ids.present?
        @error_options = { contact_segment_ids: { list: bad_contact_segment_ids.join(', ').to_s } }
      end
    end

    def validate_company_segment_ids
      valid_company_segment_ids = Account.current.company_filters.where(id: @company_folders_attributes).pluck(:id)
      if valid_company_segment_ids.size != @company_folders_attributes.size
        bad_company_segment_ids = @company_folders_attributes - valid_company_segment_ids
        errors[:company_segment_ids] << :invalid_list if bad_company_segment_ids.present?
        @error_options = { company_segment_ids: { list: bad_company_segment_ids.join(', ').to_s } }
      end
    end

    def validate_company_ids
      valid_customer_ids = Account.current.customers.where(id: @customer_folders_attributes).pluck(:id)
      if valid_customer_ids.size != @customer_folders_attributes.size
        bad_customer_ids = @customer_folders_attributes - valid_customer_ids
        errors[:company_ids] << :invalid_list if bad_customer_ids.present?
        @error_options = { company_ids: { list: bad_customer_ids.join(', ').to_s } }
      end
    end

    def validate_category_translation
      language = Language.find_by_code(@language_code)
      errors[:category_id] = :invalid_category_translation if Account.current.solution_folder_meta.find_by_id(@id).solution_category_meta.safe_send("#{language.to_key}_category").nil?
    end
  end
end
