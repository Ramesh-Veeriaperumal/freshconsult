module ApiSearchConstants
  FIELDS = ['query']
  QUERY_SIZE = 512
  STRING_WITHIN_QUOTES = /\"(.*)\"/

  TICKET_FIELDS = %w( priority status group_id requester_id email )
  CONTACT_FIELDS = %w( company_id twitter_id email mobile phone )
  COMPANY_FIELDS = %w( domain )
  ALLOWED_CUSTOM_FIELD_TYPES = %w( custom_text custom_number custom_checkbox )


  ES_KEYS = { email: :emails, company_id: :company_ids, domain: :domains }
  PRE_FETCH = { ticket: { email: :requester_id } }
end.freeze
