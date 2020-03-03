class JWT::SecureServiceJWEFactory
  def initialize(ticket, action, portal_type, custom_fields = {})
    @ticket = ticket
    @custom_fields_in_params = custom_fields
    @action = action
    @portal_type = portal_type
  end

  def generate_jwe_payload(secure_field_methods_object)
    jwe_payload = {
      iss: PciConstants::ISSUER + '/' + PodConfig['CURRENT_POD'],
      iat: Time.now.to_i,
      exp: Time.now.to_i + PciConstants::EXPIRY_DURATION,
      accid: Account.current.id,
      otype: PciConstants::OBJECT_TYPE,
      oid: @ticket.id,
      scope: jwe_payload_scope(@action, secure_field_methods_object),
      action: @action,
      uuid: Thread.current[:message_uuid],
      user_id: User.current.id,
      portal: @portal_type
    }
    key = OpenSSL::PKey::RSA.new(PciConstants::PUBLIC_KEY)
    JWE.encrypt(jwe_payload.to_json, key, enc: 'A256GCM')
  end

  private

    def jwe_payload_scope(action, secure_field_methods_object)
      # Gives the list of secure ticket fields' names to payload
      @scope = []
      case action
      when 1
        @scope << TicketDecorator.display_name(secure_field_methods_object.secure_fields_from_cache.first.name)
      when 2
        secure_field_methods_object.secure_fields(@custom_fields_in_params).each { |secure_field| @scope << TicketDecorator.display_name(secure_field) }
      end
      @scope
    end
end
