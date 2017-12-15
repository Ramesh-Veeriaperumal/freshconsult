class ContactMergeValidation < ApiValidation
  attr_accessor :primary_id, :target_ids

  validates :primary_id, required: true, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false }
  validates :target_ids, required: true, data_type: { rules: Array, allow_nil: false }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false } }

  def initialize(request_params, item, _allow_string_param = false)
    super(request_params, item)
  end
end
