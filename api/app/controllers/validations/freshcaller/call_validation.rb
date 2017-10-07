class Freshcaller::CallValidation < ApiValidation
  attr_accessor :fc_call_id, :recording_status, :call_status, :call_type, :call_created_at, :customer_number, :agent_number,
                :customer_location, :duration, :agent_email, :ticket_display_id, :note, :contact_id

  validates :fc_call_id, required: true, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }
  validates :recording_status, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }
  validates :call_status, data_type: { rules: String }
  validates :call_status, custom_inclusion: { in: Freshcaller::CallConstants::ALLOWED_CALL_STATUS_PARAMS }, data_type: { rules: String }
  validates :call_type, data_type: { rules: String }

  validates :call_created_at, data_type: { rules: String }

  validates :customer_number, data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :agent_number, data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }

  validates :customer_location, data_type: { rules: String }

  validates :duration, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }

  validates :agent_email, data_type: { rules: String, allow_nil: true }
  validates :agent_email, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address', allow_nil: true }

  validates :ticket_display_id, data_type: { rules: String }
  validates :note, data_type: { rules: String }
  validates :contact_id, data_type: { rules: String }
end
