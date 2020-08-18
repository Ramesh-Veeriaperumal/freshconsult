module ApiSolutions
  class FolderDelegator < BaseDelegator
    include Helpdesk::TagMethods
    include SolutionConcern

    attr_accessor :contact_folders_attributes, :company_folders_attributes, :customer_folders_attributes, :tag_attributes, :id, :platforms, :icon_attribute

    validate :validate_contact_segment_ids, if: -> { @contact_folders_attributes.present? }
    validate :validate_company_segment_ids, if: -> { @company_folders_attributes.present? }
    validate :validate_company_ids, if: -> { @customer_folders_attributes.present? }
    validate :validate_category_translation, on: :create, if: -> { @id && @language_code }
    validate :create_tag_permission, if: -> { @tag_attributes.present? }
    validate :validate_platform_present, on: :update, if: -> { @tag_attributes.present? && @platforms.blank? }
    validate :validate_portal_id, if: -> { @portal_id }
    validate :icon_exists_and_valid_type?, if: -> { @icon_attribute.present? }

    def initialize(options)
      options.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
      super(options)
    end

    def icon_exists_and_valid_type?
      attachment = Account.current.attachments.where('id=? and attachable_type=?', icon_attribute, "#{AttachmentConstants::INLINE_ATTACHABLE_NAMES_BY_TOKEN[:solution]} Upload")
      if attachment.empty?
        errors[:icon] << :invalid_icon_id
        (self.error_options ||= {}).merge!(icon: { invalid_id: @icon_attribute })
      else
        extension = File.extname(attachment.first.content_file_name)
        valid_extension = SolutionConstants::ICON_EXT.include?(extension)
        unless valid_extension
          errors[:icon] << :upload_jpg_or_png_file
          (self.error_options ||= {}).merge!(icon: { current_extension: extension })
        end
      end
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

    def create_tag_permission
      @tags = construct_tags(@tag_attributes)
      new_tag = @tags.find(&:new_record?)
      if new_tag && !User.current.privilege?(:create_tags)
        errors[:tags] << 'cannot_create_new_tag'
        @error_options[:tags] = { tags: new_tag.name }
      end
    end

    def validate_platform_present
      folder_meta = Account.current.solution_folder_meta.where(id: @id).first
      errors[:tags] << 'cannot_set_tag_without_platforms_enabled' if folder_meta.solution_platform_mapping.blank?
    end
  end
end
