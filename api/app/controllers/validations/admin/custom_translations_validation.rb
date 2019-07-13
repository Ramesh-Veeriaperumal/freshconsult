class Admin::CustomTranslationsValidation < ApiValidation
  attr_accessor :object_type, :object_id

  validates :object_type, custom_inclusion: { in: Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS.keys, allow_nil: true }, on: :download
  validates :object_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param, allow_nil: true }
  validate :validate_object_id, if: -> { errors[:object_type].blank? & object_id.present? }

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
