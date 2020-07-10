class Admin::CustomTranslationsValidation < ApiValidation
  include ActionView::Helpers::NumberHelper

  attr_accessor :object_type, :object_id, :language_code, :translation_file

  validates :object_type, custom_inclusion: { in: Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS.keys.map(&:to_s), allow_nil: true }
  validates :object_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param, allow_nil: true }
  validates :language_code, custom_inclusion: { in: proc { |x| Account.current.all_languages }, allow_nil: true }, on: :download
  validates :language_code, :object_id, :object_type, required: true, on: :upload
  validate :validate_missing_type, on: :download
  validate :validate_empty_file, on: :upload
  validate :validate_file_size, if: -> { errors.blank? }, on: :upload
  validate :validate_translation_file_extn, if: -> { errors.blank? }, on: :upload
  validate :validate_translation_file, if: -> { errors.blank? }, on: :upload
  validate :validate_yaml_code, if: -> { errors.blank? }, on: :upload

  # Reject uploaded files which are more than the specific file size limit

  def validate_file_size
    file_size_limit = Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS[object_type][:file_size_limit]
    return if file_size_limit.nil?

    if translation_file.size > file_size_limit
      errors[:translation_file] << :file_size_limit_error
      error_options[:translation_file] = { file_size: number_to_human_size(file_size_limit) }
    end
  end

  def validate_empty_file
    if translation_file.blank? || translation_file.class == String
      errors[:translation_file] << :no_file_uploaded
      error_options[:translation_file] = { code: :missing_field }
    end
  end

  # Reject files with invalid yaml content

  def validate_translation_file
    Psych.safe_load(File.open(@translation_file.tempfile))
  rescue Psych::SyntaxError => e
    errors[:translation_file] << :"#{e.message}"
  rescue StandardError
    errors[:translation_file] << :invalid_yml_file
  end

  def validate_translation_file_extn
    valid_extensions = Admin::CustomTranslationsConstants::SUPPORTED_FILE_EXTN
    current_extension = @translation_file.original_filename.split('.').last
    unless valid_extensions.include?(current_extension)
      errors[:translation_file] << :invalid_upload_file_type
      error_options[:translation_file] = { current_extension: current_extension }
    end
  end

  # Validates given language code with the language code given in the uploaded file.

  def validate_yaml_code
    yaml_file = Psych.safe_load(File.open(@translation_file.tempfile))
    errors[:translation_file] << :invalid_yml_file && return unless yaml_file.keys.first
    errors[:translation_file] << :mismatch_language && return if yaml_file.keys.first.to_s != @language_code
    errors[:translation_file] << :invalid_yml_file && return unless yaml_file[@language_code]['custom_translations']
  end

  # this method is only for download. If download query params has only object id & doesnt have object type.
  # vice versa is allowed.

  def validate_missing_type
    if object_type.blank? && object_id
      errors[:object_type] << :missing_param
      error_options[:object_type] = { code: :missing_field }
    end
  end
end
