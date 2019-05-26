class ApiSolutions::FolderValidation < ApiValidation
  CHECK_PARAMS_SET_FIELDS = %w[company_ids visibility article_order].freeze
  attr_accessor :name, :description, :visibility, :company_ids, :article_order, :category_id
  validates :name, data_type: { rules: String, required: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :description, data_type: { rules: String, allow_nil: true  }

  validates :visibility, required: true, unless: :secondary_language?, on: :create
  validates :visibility, custom_absence: { message: :cant_set_for_secondary_language }, if: :secondary_language?
  validates :visibility, custom_inclusion: { in: Solution::Constants::VISIBILITY_NAMES_BY_KEY.keys, detect_type: true }

  validates :company_ids, custom_absence: { message: :cant_set_company_ids }, if: -> { (errors[:visibility].blank? && company_ids_not_allowed?) }
  validates :company_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true } }, custom_length: { maximum: Solution::Constants::COMPANIES_LIMIT, message_options: { element_type: :elements } }, unless: -> { errors[:visibility].present? || company_ids_not_allowed? }

  validates :article_order, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field, message_options: { attribute: 'article_order', feature: :auto_article_order } }, unless: :auto_article_order_enabled?
  validates :article_order, custom_inclusion: { in: Solution::Constants::ARTICLE_ORDER_COLUMN_BY_TYPE.keys, detect_type: true }

  validates :category_id, custom_numericality: { only_integer: true, greater_than: 0 }, if: -> { category_id }

  def initialize(request_params, item, lang_id)
    super(request_params, item)
    @lang_id = lang_id
    @visibility ||= item.parent.visibility if item.respond_to?(:visibility) && !request_params.key?(:visibility)
  end

  private

    def secondary_language?
      @lang_id != Account.current.language_object.id
    end

    def company_ids_not_allowed?
      @company_ids_not_allowed ||= visibility != Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]
    end

    def attributes_to_be_stripped
      SolutionConstants::FOLDER_ATTRIBUTES_TO_BE_STRIPPED
    end

    def auto_article_order_enabled?
      Account.current.auto_article_order_enabled?
    end
end
