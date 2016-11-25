module ApiSearchConstants
  FIELDS = ['query']
  QUERY_SIZE = 512
  STRING_WITHIN_QUOTES = /\"(.*)\"/

  TICKET_FIELDS = %w( priority status group_id requester_id email )
  ALLOWED_TICKET_FIELD_TYPES = %w( custom_text custom_number custom_checkbox )

  ES_KEYS = { email: :emails }
  PRE_FETCH = { email: :requester_id }
end.freeze
