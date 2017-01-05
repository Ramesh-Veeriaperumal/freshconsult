class TodoValidation < FilterValidation
  attr_accessor :body, :ticket_id, :user_id, :completed

  validates :body, data_type: { rules: String, allow_nil: false }
  validates :body, custom_length: { maximum: 120 }
  validates :ticket_id, custom_numericality: { only_integer: true, allow_nil: true, ignore_string: :allow_string_param }
  validates :user_id, custom_numericality: { only_integer: true, allow_nil: true }
  validates :completed, data_type: { rules: 'Boolean' }
end
