class ApiSolutions::ArticleValidation < ApiValidation
  attr_accessor :title, :description, :user_id, :status, :type, :tags, :seo_data, :meta_title, :meta_keywords,
                :meta_description, :folder_name, :category_name
  validates :title, data_type: { rules: String, required: true }, custom_length: { maximum: SolutionConstants::TITLE_MAX_LENGTH, minimum: SolutionConstants::TITLE_MIN_LENGTH, message: :too_long_too_short }
  validates :meta_title, data_type: { rules: String, allow_nil: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :description, data_type: { rules: String, required: true }
  validates :meta_description, data_type: { rules: String, allow_nil: true }
  validates :user_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }, on: :update
  validates :status, custom_inclusion: { in: Solution::Article::STATUS_NAMES_BY_KEY.keys,  detect_type: true, required: true }

  # type is allowed only during creation/alteration of article in primary language
  validates :type, required: true, if: -> { @lang_id == Account.current.language_object.id }, on: :create
  validates :type, custom_absence: { message: :cant_set_art_type }, if: -> { @lang_id != Account.current.language_object.id }
  validates :type, custom_inclusion: { in: Solution::Article::TYPE_NAMES_BY_KEY.keys,  detect_type: true }

  validates :seo_data, data_type: { rules: Hash }

  validates :tags, :meta_keywords, data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: String, allow_nil: true }, custom_length: { maximum: ApiConstants::TAG_MAX_LENGTH_STRING } }
  validates :tags, :meta_keywords, string_rejection: { excluded_chars: [','] }

  validates :folder_name, :category_name, data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :folder_name, :category_name, custom_absence: { message: :attribute_not_required }, if: -> { @lang_id == Account.current.language_object.id }

  def initialize(request_params, item, lang_id)
    super(request_params, item)
    @lang_id = lang_id

    if request_params[:seo_data].is_a?(Hash)
      seo_data = request_params[:seo_data]
      @meta_title = seo_data['meta_title']
      @meta_description = seo_data['meta_description']
      @meta_keywords = seo_data['meta_keywords']
    end

    check_params_set(request_params.slice(*SolutionConstants::ARTICLE_CHECK_PARAMS_SET_FIELDS))
  end

  private

    def attributes_to_be_stripped
      SolutionConstants::ARTICLE_ATTRIBUTES_TO_BE_STRIPPED
    end
end
