class Admin::CustomTranslationsValidation < ApiValidation
  include ActionView::Helpers::NumberHelper

  attr_accessor :object_type, :object_id, :language_code, :translation_file

  validates :object_type, custom_inclusion: { in: Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS.keys.map(&:to_s), allow_nil: true }
  validates :object_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param, allow_nil: true }
  validates :language_code, custom_inclusion: { in: proc { |x| Account.current.all_languages }, allow_nil: true }, on: :download
  validate :validate_object_id, if: -> { errors[:object_type].blank? & object_id.present? }
  validate :validate_translation_file, on: :upload
  validate :validate_file_size, if: -> { errors.blank? }, on: :upload
  validate :validate_language_code, if: -> { errors.blank? }, on: :upload
  validate :validate_for_supported_languages, if: -> { errors.blank? }, on: :upload
  validate :validate_yaml_code, if: -> { errors.blank? }, on: :upload

  def validate_file_size
    file_size_limit = Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS[object_type][:file_size_limit]
    return if file_size_limit.nil?

    if translation_file.size > file_size_limit
      errors[:translation_file] << :file_size_limit_error
      error_options[:translation_file] = { file_size: number_to_human_size(file_size_limit) }
    end
  end

  def validate_translation_file
    if translation_file.blank? || translation_file.class == String
      errors[:translation_file] << :no_file_uploaded
    else
      valid_extensions = ['yaml', 'yml']
      current_extension = @translation_file.original_filename.split('.').last
      unless valid_extensions.include?(current_extension)
        errors[:translation_file] << :invalid_upload_file_type
        error_options[:translation_file] = { current_extension: current_extension }
      end
    end
  end

  def validate_language_code
    errors[:translation_file] << :primary_lang_translations_not_allowed && return if @language_code == Account.current.language
  end

  def validate_yaml_code
    yaml_file = YAML.safe_load(File.foreach(@translation_file.tempfile).first(2).join)
    yaml_lang_code = yaml_file.respond_to?(:keys) ? yaml_file.keys.last : nil
    errors[:translation_file] << :invalid_yml_file && return if yaml_lang_code.blank?
    errors[:translation_file] << :mismatch_language && return if yaml_lang_code.to_s != @language_code
  end

  def validate_for_supported_languages
    permitted_language_list = Account.current.supported_languages
    if Language.find_by_code(@language_code).blank? || !permitted_language_list.include?(@language_code)
      errors[:translation_file] << :unsupported_language
      error_options[:translation_file] = { language_code: @language_code.to_s, list: permitted_language_list.sort.join(', ') }
    end
  end

  def validate_object_id
    if object_type.blank?
      errors[:object_type] << :missing_param
      error_options[:object_type] = { code: :missing_field }
      return
    end

    object_mapping = Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS[object_type]
    items = Account.current.safe_send(object_type)
    items = items.where(object_mapping[:conditions]) if object_mapping[:conditions].present?
    if items.where(id: object_id).first.blank?
      errors[:object_id] << :invalid_object_id
      error_options[:object_id] = { object: object_type }
    end
  end
end
