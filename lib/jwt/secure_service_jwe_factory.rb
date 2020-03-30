class JWT::SecureServiceJWEFactory
  def initialize(action, object_id = 0, portal_type = PciConstants::PORTAL_TYPE[:agent_portal], object_type = PciConstants::OBJECT_TYPE[:ticket], custom_fields = {})
    @object_id = object_id
    @object_type = object_type
    @custom_fields_in_params = custom_fields
    @action = action
    @portal_type = portal_type
    @account = Account.current
  end

  def generate_jwe_payload(secure_field_methods_object = nil)
    get_payload(secure_data_hash(secure_field_methods_object))
  end

  def account_info_payload
    organisation_id = @account.freshid_org_v2_enabled? && @account.organisation_from_cache.try(:organisation_id)
    get_payload(basic_hash.merge(organisation_id ? { org_id: organisation_id } : {}))
  end

  def bulk_delete_payload(object_ids = [])
    get_payload(secure_data_hash.merge(bulk_oids: object_ids))
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

    def secure_data_hash(secure_field_methods_object = nil)
      {
        otype: @object_type,
        oid: @object_id,
        scope: jwe_payload_scope(@action, secure_field_methods_object),
        portal: @portal_type
      }.merge(basic_hash)
    end

    def get_payload(payload_hash)
      key = OpenSSL::PKey::RSA.new(PciConstants::PUBLIC_KEY)
      JWE.encrypt(payload_hash.to_json, key, enc: 'A256GCM')
    end

    def jwe_payload_scope(action, secure_field_methods_object)
      # Gives the list of secure ticket fields' names to payload
      @scope = []
      case action
      when PciConstants::ACTION[:read]
        @scope << TicketDecorator.display_name(secure_field_methods_object.secure_fields_from_cache.first.name)
      when PciConstants::ACTION[:write]
        secure_field_methods_object.secure_fields(@custom_fields_in_params).each { |secure_field| @scope << TicketDecorator.display_name(secure_field) }
      when PciConstants::ACTION[:delete]
        @scope.concat(@custom_fields_in_params)
      end
      @scope
    end
end
