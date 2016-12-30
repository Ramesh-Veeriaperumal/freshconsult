class AttachmentValidation < ApiValidation
  CHECK_PARAMS_SET_FIELDS = %w(user_id inline_type).freeze

  attr_accessor :user_id, :content, :inline, :inline_type

  validates :user_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param }
  validates :content, required: true, data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: false }, file_size: { max: ApiConstants::ALLOWED_ATTACHMENT_SIZE }
  validates :inline, data_type: { rules: 'Boolean',  ignore_string: :allow_string_param }
  validates :user_id, custom_absence: { allow_nil: false, message: :cannot_set_user_id }, if: -> { is_inline? }
  validates :inline_type, custom_absence: { allow_nil: false, message: :cannot_set_inline_type }, unless: -> { is_inline? }
  validates :inline_type, custom_inclusion: { in: AttachmentConstants::INLINE_ATTACHABLE_NAMES_BY_KEY.keys, ignore_string: :allow_string_param, detect_type: true }, if: -> { errors[:inline_type].blank? }
  validates :inline_type, required: true, if: -> { is_inline? }

  validate :validate_file_type, if: -> { errors[:content].blank? && is_inline? }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end

  def validate_file_type
    valid_extension, extension = extension_valid?(content)
    unless valid_extension
      errors[:content] << :invalid_image_file
      error_options[:content] = { current_extension: extension }
    end
  end

  private
  
    def extension_valid?(file)
      ext = File.extname(file.respond_to?(:original_filename) ? file.original_filename : file.content_file_name).downcase
      [AttachmentConstants::INLINE_IMAGE_EXT.include?(ext), ext]
    end

    def is_inline?
      inline.try(:to_s) == 'true'
    end
end
