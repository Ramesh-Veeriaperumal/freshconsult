module ApiBotTicketConstants
  # ControllerConstants
  CREATE_FIELDS = (ApiTicketConstants::CREATE_FIELDS - %w[source] + %w[bot_external_id query_id conversation_id]).freeze
end
