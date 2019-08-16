module Admin::CustomTranslationsConstants
  MODULE_MODEL_MAPPINGS = {
    'surveys' => { model: 'custom_surveys', conditions: 'deleted = false', lookup_key: 'id' }
  }.freeze

  VALIDATION_CLASS = 'Admin::CustomTranslationsValidation'.freeze
  DOWNLOAD_FIELDS = ['object_type', 'object_id', 'language_code'].freeze
  LOAD_OBJECT_EXCEPT = ['download', 'upload'].freeze
  UPLOAD_FIELDS = ['object_type', 'object_id', 'language_code', 'translation_file', 'custom_translation'].freeze
  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    upload: [:multipart_form]
  }.freeze
end
