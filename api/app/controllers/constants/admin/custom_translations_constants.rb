module Admin::CustomTranslationsConstants
  MODULE_MODEL_MAPPINGS = {
    'surveys' => { model: 'custom_surveys', conditions: 'deleted = false' }
  }.freeze

  VALIDATION_CLASS = 'Admin::CustomTranslationsValidation'.freeze
  DOWNLOAD_FIELDS = ['object_type', 'object_id'].freeze
  LOAD_OBJECT_EXCEPT = ['download'].freeze
end
