module ApiIntegrations
  module CtiConstants
    SCREEN_POP_FIELDS = %w(requester_id requester_phone responder_id responder_phone call_reference_id ticket_id new_ticket call_url)
    EXCLUDE_FIELDS = [:ticket_id, :requester_phone, :responder_phone, :call_info, :new_ticket, :call_url]
    INDEX_FIELDS = %w(call_reference_id).freeze
    RENAME_ERROR_FIELDS = { requester: :requester_id, responder: :responder_id }.freeze
    FEATURE_NAME = 'cti'.freeze
  end
end
