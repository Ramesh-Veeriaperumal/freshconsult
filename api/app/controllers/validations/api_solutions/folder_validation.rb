class ApiSolutions::FolderValidation < ApiValidation
  attr_accessor :name, :description, :visibility, :company_ids
  validates :name, data_type: { rules: String, required: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :description, data_type: { rules: String, allow_nil: true  }

  validates :visibility, custom_inclusion: { in: Solution::Constants::VISIBILITY_NAMES_BY_KEY.keys,  detect_type: true, required: true }, if: -> { @lang_id == Account.current.language_object.id }, on: :create
  validates :visibility, custom_inclusion: { in: Solution::Constants::VISIBILITY_NAMES_BY_KEY.keys,  detect_type: true }, if: -> { visibility && visibility_can_be_altered? }

  validates :company_ids, custom_absence: { message: :cant_set_company_ids }, if: -> { errors[:visibility].blank? && company_ids_not_allowed? }
  validates :company_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true } }, custom_length: { maximum: Solution::Constants::COMPANIES_LIMIT, message_options: { element_type: :elements } }, unless: -> { errors[:visibility].present? || company_ids_not_allowed? }

  def initialize(request_params, item, lang_id)
    super(request_params, item)
    @lang_id = lang_id
    check_params_set(request_params.slice(*SolutionConstants::FOLDER_CHECK_PARAMS_SET_FIELDS))
  end

  private

    def company_ids_not_allowed?
      @company_ids_not_allowed ||= visibility != Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]
    end

    # Visibility can be updated only during create/update primary translation of the folder
    def visibility_can_be_altered?
      unless Account.current.language_object.id == @lang_id
        errors[:visibility] << :invalid_field
        return false
      end
    end

    def attributes_to_be_stripped
      SolutionConstants::FOLDER_ATTRIBUTES_TO_BE_STRIPPED
    end
end
