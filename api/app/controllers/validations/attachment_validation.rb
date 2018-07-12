class AttachmentValidation < ApiValidation
  CHECK_PARAMS_SET_FIELDS = %w(user_id inline_type).freeze
  include EmailServRequest::Validator

  attr_accessor :user_id, :content, :inline, :inline_type, :attachable_id, :attachable_type

  validates :user_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param }
  validates :content, required: true, data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: false }, 
    file_size: { max: proc { |x| x.attachment_limit } }, on: :create
  validates :inline, data_type: { rules: 'Boolean', ignore_string: :allow_string_param }
  validates :user_id, custom_absence: { allow_nil: false, message: :cannot_set_user_id }, if: -> { inline? }
  validates :inline_type, custom_absence: { allow_nil: false, message: :cannot_set_inline_type }, unless: -> { inline? }
  validates :inline_type, custom_inclusion: { in: AttachmentConstants::INLINE_ATTACHABLE_NAMES_BY_KEY.keys, ignore_string: :allow_string_param, detect_type: true }, if: -> { errors[:inline_type].blank? }
  validates :inline_type, required: true, if: -> { inline? }

  validate :validate_file_type, if: -> { errors[:content].blank? && inline? }
  validate :virus_in_attachment?, if: -> { attachment_virus_detection_enabled? && errors[:content].blank? }

  validates :attachable_id, required: true, custom_numericality: {
    only_integer: true, greater_than: 0,
    allow_nil: false, ignore_string: :allow_string_param
  }, on: :unlink

  validates :attachable_type, required: true, custom_inclusion: {
    in: AttachmentConstants::ATTACHABLE_TYPES.keys,
    ignore_string: :allow_string_param
  }, on: :unlink

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

    def attachment_virus_detection_enabled?
      Account.current.launched?(:attachment_virus_detection)
    end

    def virus_in_attachment?
      if content && content.original_filename && content.tempfile
        files = {}
        files[content.original_filename] = Faraday::UploadIO.new(content.tempfile, content.content_type)
        results = is_attachment_has_virus?(files)
        virus_files = results.select { |file| file['Result'] == "VIRUS_FOUND" }
        errors[:content] << :virus_found_in_file if virus_files.present?
      end
    end

    def extension_valid?(file)
      ext = File.extname(file.respond_to?(:original_filename) ? file.original_filename : file.content_file_name).downcase
      ext = AttachmentConstants::BLOB_MAPPING[file.content_type] if ext.blank?
      [AttachmentConstants::INLINE_IMAGE_EXT.include?(ext), ext]
    end

    def inline?
      inline.try(:to_s) == 'true'
    end
end
