class JWT::SecureFieldMethods
  def get_jwe_token(custom_fields, item_id, portal_type)
    # Generates JWE token
    jwe = JWT::SecureServiceJWEFactory.new(PciConstants::ACTION[:write], item_id, portal_type, PciConstants::OBJECT_TYPE[:ticket], custom_fields)
    jwe.generate_jwe_payload(self)
  end

  def name_mapped_secure_fields
    # {:secure_text_1 => :_secure_text } for secure fields and {:text_1 => :text} for all other fields
    @name_mapped_secure_fields ||= TicketsValidationHelper.name_mapping(secure_fields_from_cache)
  end

  def secure_fields_from_cache
    # Retrieves the secure fields from cache
    @secure_fields_from_cache ||= Account.current.ticket_fields_from_cache.reject(&:default).select { |c| [TicketFieldsConstants::SECURE_TEXT].include?(c.field_type) }
  end

  def secure_fields(custom_fields)
    custom_fields.keys & name_mapped_secure_fields.keys
  end
end
