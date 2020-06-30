class ApiSolutions::ArticleValidation < ApiValidation
  CHECK_PARAMS_SET_FIELDS = %w[type folder_name category_name].freeze
  attr_accessor :title, :description, :agent_id, :status, :type, :tags,
                :seo_data, :meta_title, :meta_keywords, :meta_description,
                :folder_name, :category_name, :attachments, :attachments_list, :cloud_file_attachments, :folder_id,
                :item, :attachable, :outdated, :prefer_published, :templates_used, :platforms

  validates :title, required: true, on: :create
  validates :title, data_type: { rules: String }, custom_length: { maximum: SolutionConstants::TITLE_MAX_LENGTH, minimum: SolutionConstants::TITLE_MIN_LENGTH, message: :too_long_too_short }
  validates :meta_title, data_type: { rules: String, allow_nil: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :description, required: true, on: :create
  validates :description, data_type: { rules: String }
  validates :meta_description, data_type: { rules: String, allow_nil: true }
  validates :agent_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }, on: :update
  validates :status, custom_inclusion: {
    in: [Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], Solution::Article::STATUS_KEYS_BY_TOKEN[:published]],
    ignore_string: :allow_string_param,
    detect_type: true,
    required: true
  }

  # type is allowed only during creation/alteration of article in primary language
  # validates :type, required: true, if: -> { @lang_id == Account.current.language_object.id }, on: :create
  validates :type, custom_absence: { message: :cant_set_for_secondary_language }, if: -> { @lang_id != Account.current.language_object.id }
  validates :type, custom_inclusion: {
    in: Solution::Article::TYPE_NAMES_BY_KEY.keys,
    ignore_string: :allow_string_param,
    detect_type: true
  }

  validates :seo_data, data_type: { rules: Hash }

  validates :tags, :meta_keywords, data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: String, allow_nil: true }, custom_length: { maximum: ApiConstants::TAG_MAX_LENGTH_STRING } }
  validates :tags, :meta_keywords, string_rejection: { excluded_chars: [','] }

  validates :folder_name, :category_name, data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :folder_name, :category_name, custom_absence: { message: :attribute_not_required }, if: -> { @lang_id == Account.current.language_object.id }

  # Attachment validations
  validates :attachments, data_type: {
    rules: Array, allow_nil: true
  }, array: {
    data_type: {
      rules: ApiConstants::UPLOADED_FILE_TYPE,
      allow_nil: false
    }
  }
  validates :attachments, file_size: {
    max: proc { |x| x.attachment_limit },
    base_size: proc { |x| ValidationHelper.attachment_size(x.attachable) }
  }

  validates :attachments_list, data_type: { rules: Array, allow_nil: false }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false } }
  validates :cloud_file_attachments, data_type: { rules: Array, allow_nil: false }
  validates :cloud_file_attachments, array: { data_type: { rules: Hash, allow_nil: false } }
  validate :validate_cloud_files, if: -> { cloud_file_attachments.present? && errors[:cloud_file_attachments].blank? }
  validates :folder_id, data_type: { rules: Integer, allow_nil: false }
  validates :outdated,  data_type: { rules: 'Boolean' }
  validates :prefer_published, data_type: { rules: 'Boolean' }
  validates :templates_used, data_type: { rules: Array, allow_nil: false }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false } }
  validates :platforms, data_type: { rules: Hash, allow_nil: false }, hash: { validatable_fields_hash: proc { |x| x.validate_platform_values } }, if: -> { create_or_update? }

  def initialize(request_params, article, attachable, lang_id, allow_string_param = false)
    super(request_params, article, allow_string_param)
    @lang_id = lang_id
    @attachable = attachable
    @attachments_list = request_params[:attachments_list] if request_params[:attachments_list]
    @cloud_file_attachments = request_params[:cloud_file_attachments] if request_params[:cloud_file_attachments]
    @folder_id = request_params[:folder_id] if request_params[:folder_id]
    @outdated = request_params[:outdated] if request_params[:outdated]

    if request_params[:seo_data].is_a?(Hash)
      seo_data = request_params[:seo_data]
      @meta_title = seo_data['meta_title']
      @meta_description = seo_data['meta_description']
      @meta_keywords = seo_data['meta_keywords']
    end
  end

  def validate_platform_values
    {
      web: { data_type: { rules: 'Boolean', allow_nil: false } },
      ios: { data_type: { rules: 'Boolean', allow_nil: false } },
      android: { data_type: { rules: 'Boolean', allow_nil: false } }
    }
  end

  private

    def attributes_to_be_stripped
      SolutionConstants::ARTICLE_ATTRIBUTES_TO_BE_STRIPPED
    end

    def validate_cloud_files
      cloud_file_hash_errors = []
      @cloud_file_attachments.each_with_index do |cloud_file, index|
        cloud_file_validator = CloudFileValidation.new(cloud_file, nil)
        cloud_file_hash_errors << cloud_file_validator.errors.full_messages unless cloud_file_validator.valid?
      end
      errors[:cloud_file_attachments] << :"is invalid" if cloud_file_hash_errors.present?
    end
end
