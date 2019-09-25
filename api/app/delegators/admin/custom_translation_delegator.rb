class Admin::CustomTranslationDelegator < BaseDelegator
  attr_accessor :user_hash, :language_code, :object_id, :object_type
  validate :validate_object_type, if: -> { errors.blank? && object_type && user_hash }
  validate :validate_object_id, if: -> { errors.blank? && object_id }
  validate :validate_object_entity, if: -> { errors.blank? && object_id && user_hash }
  validate :validate_language_code, if: -> { errors.blank? && language_code && user_hash }
  validate :validate_for_supported_languages, if: -> { errors.blank? && language_code && user_hash }

  def initialize(options)
    @user_hash = options[:uploaded_hash]
    @language_code = options[:language_code]
    @object_id = options[:object_id]
    @object_type = options[:object_type]
    super(options)
  end

  # Validate whether the corresponding hash is present for the given object_type.

  def validate_object_type
    errors[:object_type] << :empty_entity unless user_hash[language_code]['custom_translations'][object_type]
  end

  # Validate the given object_id in query param is valid or not.

  def validate_object_id
    object_mapping = Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS[object_type]
    items = Account.current.safe_send(object_mapping[:model])
    items = items.where(object_mapping[:conditions]) if object_mapping[:conditions].present?
    @record = items.where(id: object_id).first
    if @record.blank?
      errors[:object_id] << :invalid_object_id
      error_options[:object_id] = { object: object_type }
    end
  end

  # Validate whether the given object id has corresponding hash in uploaded file or not.

  def validate_object_entity
    if user_hash[language_code]['custom_translations'][object_type][@record.custom_translation_key].blank?
      errors[:object_id] << :invalid_entity 
      error_options[:object_id] = { object: object_type.singularize }
    end
  end

  # Primary language is not allowed for upload

  def validate_language_code
    errors[:language_code] << :primary_lang_translations_not_allowed && return if language_code == Account.current.language
  end

  def validate_for_supported_languages
    permitted_language_list = Account.current.supported_languages
    if Language.find_by_code(language_code).blank? || !permitted_language_list.include?(language_code)
      errors[:language_code] << :unsupported_language
      error_options[:language_code] = { language_code: language_code.to_s, list: permitted_language_list.sort.join(', ') }
    end
  end
end
