module AuditLog::Translators::Company
  def readable_company_changes(model_changes)
    keys_to_change = Company::TAM_DEFAULT_FIELD_MAPPINGS.keys
    custom_fields = []
    model_changes.keys.each do |attribute|
      if keys_to_change.include? attribute
        model_changes[Company::TAM_DEFAULT_FIELD_MAPPINGS[attribute]] = model_changes.delete(attribute)
      elsif attribute.to_s.start_with? 'cf_'
        old_key = attribute.to_s
        is_encrpted_value = old_key.start_with? 'cf_enc_'
        new_key = is_encrpted_value ? old_key[7, old_key.length].to_sym : old_key[3, old_key.length].to_sym
        model_changes[new_key] = if is_encrpted_value
                                   [Company::ENCRYPTED_VALUE_MASK, Company::ENCRYPTED_VALUE_MASK]
                                 else
                                   model_changes[attribute]
                                 end
        model_changes.delete(attribute)
        custom_fields.push(new_key)
      elsif attribute.eql? :avatar
        old_avatar = model_changes[attribute][:removed][:name] if model_changes[attribute][:removed].present?
        new_avatar = model_changes[attribute][:added][:name] if model_changes[attribute][:added].present?
        model_changes.delete(attribute)
        model_changes[attribute] = [old_avatar, new_avatar]
      end
    end
    { model_changes: model_changes, custom_fields: custom_fields }
  end

  def check_bool_type(val)
    val.is_a?(TrueClass) || val.is_a?(FalseClass)
  end
end
