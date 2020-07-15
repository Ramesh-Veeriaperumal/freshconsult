class Admin::CustomTranslations::UploadValidation < ApiValidation
  attr_accessor :translation_file

  validate :validate_empty_file, if: -> { translation_file.nil? || translation_file.class == String }
  validate :validate_file_extension, if: -> { !translation_file.nil? }
  validate :validate_language_code, if: -> { !translation_file.nil? }

  def validate_empty_file
    errors[:translation_file] << :no_file_uploaded
    @translation_file = nil
  end

  def validate_file_extension
    @invalid_extension = false
    valid_extensions = ['yaml', 'yml']
    current_extension = @translation_file.original_filename.split('.').last
    unless valid_extensions.include?(current_extension)
      errors[:translation_file] << :invalid_upload_file_type
      error_options[:translation_file] = { current_extension: current_extension }
      @invalid_extension = true
    end
  end

  def validate_language_code
    return if @invalid_extension

    yaml_file = YAML.load(File.foreach(@translation_file.tempfile).first(2).join, safe: true)
    yaml_language_code = yaml_file.respond_to?(:keys) ? yaml_file.keys.last : nil
    errors[:translation_file] << :invalid_yml_file && return if yaml_language_code.nil?
    errors[:translation_file] << :mismatch_language && return if yaml_language_code.to_s != @language_code
    errors[:translation_file] << :primary_lang_translations_not_allowed && return if @language_code == Account.current.language
    permitted_language_list = Account.current.supported_languages
    if Language.find_by_code(@language_code).nil? || !permitted_language_list.include?(@language_code)
      errors[:translation_file] << :unsupported_language
      error_options[:translation_file] = { language_code: @language_code.to_s, list: permitted_language_list.sort.join(', ') }
    end
  end
end
