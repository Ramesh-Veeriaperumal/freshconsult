module Freshcaller
  module CallConstants
    CREATE_FIELDS = %w[fc_call_id].freeze
    UPDATE_FIELDS = %w[recording_status call_status call_type call_created_at customer_number
                       agent_number customer_location duration agent_email ticket_display_id
                       note contact_id subject description fc_call_id call_agent_email callback ancestry].freeze
    EXCLUDE_FIELDS = %i[call_status call_created_at customer_number agent_number fc_call_id
                        customer_location ticket_display_id note agent_email duration contact_id].freeze

    ALLOWED_CALL_STATUS_PARAMS = %w[voicemail no-answer completed in-progress on-hold default abandoned].freeze
  end
end