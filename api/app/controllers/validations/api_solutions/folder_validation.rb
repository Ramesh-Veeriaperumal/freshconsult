class ApiSolutions::FolderValidation < ApiValidation
  include SolutionHelper
  include SolutionConcern
  CHECK_PARAMS_SET_FIELDS = %w[company_ids visibility article_order contact_segment_ids company_segment_ids platforms tags icon].freeze
  attr_accessor :name, :description, :visibility, :company_ids, :article_order, :category_id, :contact_segment_ids, :company_segment_ids, :platforms, :tags, :icon

  validates :name, data_type: { rules: String, required: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :description, data_type: { rules: String, allow_nil: true  }

  validates :visibility, required: true, unless: :secondary_language?, on: :create
  validates :visibility, custom_absence: { message: :cant_set_for_secondary_language }, if: :secondary_language?
  validates :visibility, custom_inclusion: { in: Solution::Constants::VISIBILITY_NAMES_BY_KEY.keys, detect_type: true }

  validate :validate_segment_visibility, if: -> { @company_segment_ids.present? || @contact_segment_ids.present? }

  validate :validate_omni_channel_feature, if: -> { @platforms.present? || @tags.present? }

  validate :folder_icon_allowed?, if: -> { @icon.present? }
  validates :icon, custom_numericality: { only_integer: true, greater_than: 0 }, if: -> { @icon.present? }

  validates :company_ids, custom_absence: { message: :cant_set_company_ids }, if: -> { (errors[:visibility].blank? && company_ids_not_allowed?) }
  validates :company_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true } }, custom_length: { maximum: Solution::Constants::COMPANIES_LIMIT, minimum: 1, message_options: { element_type: :elements } }, unless: -> { errors[:visibility].present? || company_ids_not_allowed? }

  validates :contact_segment_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true } }, custom_length: { maximum: Solution::Constants::CONTACT_FILTER_LIMIT, minimum: 1, message_options: { element_type: :elements } }, unless: -> { errors[:visibility].present? || contact_segment_ids_not_allowed? }
  validates :contact_segment_ids, custom_absence: { message: :cant_set_contact_segment_ids }, if: -> { (errors[:visibility].blank? && contact_segment_ids_not_allowed?) }

  validates :company_segment_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true } }, custom_length: { maximum: Solution::Constants::COMPANY_FILTER_LIMIT, minimum: 1, message_options: { element_type: :elements } }, unless: -> { errors[:visibility].present? || company_segment_ids_not_allowed? }
  validates :company_segment_ids, custom_absence: { message: :cant_set_company_segment_ids }, if: -> { (errors[:visibility].blank? && company_segment_ids_not_allowed?) }

  validates :article_order, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field, message_options: { attribute: 'article_order', feature: :auto_article_order } }, unless: :auto_article_order_enabled?
  validates :article_order, custom_inclusion: { in: Solution::Constants::ARTICLE_ORDER_COLUMN_BY_TYPE.keys, detect_type: true }

  validates :category_id, custom_numericality: { only_integer: true, greater_than: 0 }, if: -> { category_id }

  validates :platforms, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.platform_format } }, allow_nil: true, unless: -> { public_api?(@version) }
  validates :platforms, data_type: { rules: Array }, array: { data_type: { rules: String, allow_nil: true },
                                                              custom_inclusion: { in: SolutionConstants::PLATFORM_TYPES } }, if: -> { public_api?(@version) }
  validates :platforms, custom_absence: { message: :cant_set_platforms }, if: -> { (errors[:visibility].blank? && platforms_not_allowed?) }

  validates :tags, data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: String, allow_nil: true }, custom_length: { maximum: ApiConstants::TAG_MAX_LENGTH_STRING } }
  validates :tags, string_rejection: { excluded_chars: [','] }
  validates :tags, custom_absence: { message: :cant_set_tags }, if: -> { (errors[:visibility].blank? && tags_not_allowed?) }
  validates :tags, custom_absence: { message: :cant_set_tags }, if: -> { @platforms.blank? }, on: :create

  def initialize(request_params, version, item, lang_id)
    super(request_params, item)
    @version = version
    @lang_id = lang_id
    @visibility = item.parent.visibility if item.respond_to?(:visibility) && !request_params.key?(:visibility)
  end

  def platform_format
    {
      ios: {
        data_type: {
          rules: 'Boolean'
        }
      },
      android: {
        data_type: {
          rules: 'Boolean'
        }
      },
      web: {
        data_type: {
          rules: 'Boolean'
        }
      }
    }
  end

  private

    def secondary_language?
      @lang_id != Account.current.language_object.id
    end

    def company_ids_not_allowed?
      @company_ids_not_allowed ||= visibility != Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]
    end

    def contact_segment_ids_not_allowed?
      if @contact_segment_ids.present?
        @contact_segment_ids_not_allowed = visibility != Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:contact_segment]
      end
    end

    def company_segment_ids_not_allowed?
      if @company_segment_ids.present?
        @company_segment_ids_not_allowed = visibility != Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_segment]
      end
    end

    def platforms_not_allowed?
      @platforms.present? && (visibility != Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone])
    end

    def tags_not_allowed?
      @tags.present? && (visibility != Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone])
    end

    def attributes_to_be_stripped
      SolutionConstants::FOLDER_ATTRIBUTES_TO_BE_STRIPPED
    end

    def folder_icon_allowed?
      omni_channel_error(:icon) unless allow_chat_platform_attributes?
      errors.blank?
    end

    def auto_article_order_enabled?
      Account.current.auto_article_order_enabled?
    end

    def validate_segment_visibility
      unless Account.current.segments_enabled?
        segment_visibility_error(:contact_segment_ids) if @contact_segment_ids.present?
        segment_visibility_error(:company_segment_ids) if @company_segment_ids.present?
      end
      errors.blank?
    end

    def segment_visibility_error(field)
      errors[:"properties[:#{field}]"] << :require_feature
      error_options[:"properties[:#{field}]"] = { feature: :segments, code: :access_denied }
    end

    def validate_omni_channel_feature
      unless Account.current.omni_bundle_account? && Account.current.launched?(:kbase_omni_bundle)
        omni_channel_error(:platforms) if @platforms.present?
        omni_channel_error(:tags) if @tags.present?
      end
      errors.blank?
    end

    def omni_channel_error(field)
      errors[:"properties[:#{field}]"] << :require_feature
      error_options[:"properties[:#{field}]"] = { feature: :omni_bundle_2020, code: :access_denied }
    end
end
