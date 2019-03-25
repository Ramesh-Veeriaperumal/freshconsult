class ArchiveValidation < ApiValidation
  attr_accessor :archive_days, :ids

  validates :archive_days, custom_numericality: { only_integer: true, allow_nil: false }
  validates :ids, data_type: { rules: Array, allow_blank: false },
                  array: { custom_numericality: { only_integer: true, greater_than: 0, allow_blank: false } },
                  custom_length: { minimum: 1, maximum: ApiConstants::MAX_ITEMS_FOR_BULK_ACTION, message_options: { element_type: :ids } }
end
