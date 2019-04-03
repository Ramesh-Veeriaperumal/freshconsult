class SolutionArticleFilterValidation < FilterValidation
  attr_accessor :user_id, :language_id, :portal_id, :author, :status, :created_at, :last_modified, 
                :category, :folder, :tags, :term

  validates :user_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }
  validates :language_id, required: true, custom_inclusion: { in: proc { |x| x.portal_languages }, 
      			  ignore_string: :allow_string_param }, if: :lang_id_dependent_actions
  validates :portal_id, required: true, data_type: { rules: String, allow_nil: false }, on: :filter
  validates :term, data_type: { rules: String }, on: :filter
  validates :author, :status, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }, on: :filter
  validates :created_at, :last_modified, data_type: { rules: Hash }, 
      			  hash: { validatable_fields_hash: proc { |x| x.date_fields_validation } }, on: :filter
  validates :category, :folder, data_type: { rules: Array }, array: { data_type: { rules: String, allow_nil: false }, 
              custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } }, on: :filter
  validates :tags, data_type: { rules: Array }, array: { data_type: { rules: String }, 
              custom_length: { maximum: ApiConstants::TAG_MAX_LENGTH_STRING } }, 
              string_rejection: { excluded_chars: [','], allow_nil: true }, on: :filter


  LANGUAGE_ID_DEPENDENT_ACTIONS = %w[index article_content].freeze

  def initialize(request_params, item = nil, allow_string_param = true)
    super(request_params, item, allow_string_param)
  end

  def portal_languages
    Account.current.all_portal_language_objects.map(&:id)
  end

  def lang_id_dependent_actions
  	LANGUAGE_ID_DEPENDENT_ACTIONS.include?(@request_params[:action])
  end

  def date_fields_validation
  	{
      start: { data_type: { rules: String, required: true } },
      end: { data_type: { rules: String, required: true } }
    }
  end
end