class JWT::SecureServiceJWEFactory
  def initialize(action, object_id = 0, portal_type = PciConstants::PORTAL_TYPE[:agent_portal], object_type = PciConstants::OBJECT_TYPE[:ticket], custom_fields = {})
    @object_id = object_id
    @object_type = object_type
    @custom_fields_in_params = custom_fields
    @action = action
    @portal_type = portal_type
    @account = Account.current
  end

  def generate_jwe_payload(secure_field_methods_object)
    jwe_payload = {
      otype: @object_type,
      oid: @object_id,
      scope: jwe_payload_scope(@action, secure_field_methods_object),
      portal: @portal_type
    }.merge(basic_hash)
    get_payload(jwe_payload)
  end

  def account_info_payload
    organisation_id = @account.freshid_org_v2_enabled? && @account.organisation_from_cache.try(:organisation_id)
    get_payload(basic_hash.merge(organisation_id ? { org_id: organisation_id } : {}))
  end

  private

    def basic_hash
      {
        iss: PciConstants::ISSUER + '/' + PodConfig['CURRENT_POD'],
        iat: Time.now.to_i,
        exp: Time.now.to_i + PciConstants::EXPIRY_DURATION,
        accid: @account.id,
        action: @action,
        uuid: Thread.current[:message_uuid],
        user_id: User.current.present? ? User.current.id : 0
      }
    end

    def get_payload(jwe_payload)
      key = OpenSSL::PKey::RSA.new(PciConstants::PUBLIC_KEY)
      JWE.encrypt(jwe_payload.to_json, key, enc: 'A256GCM')
    end

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
