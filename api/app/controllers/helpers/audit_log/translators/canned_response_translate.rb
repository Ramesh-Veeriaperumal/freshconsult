module AuditLog::Translators::CannedResponseTranslate
  def readable_canned_response_changes(model_changes)
    @groups = {}
    model_changes.keys.each do |attribute|
      case attribute
      when :folder_id
        folder_data = Account.current.canned_response_folders.inject({}) { |hash, key|
          key.personal? ? hash.merge!(key[:id] => "Personal") : hash.merge!(key[:id] => key[:name]) 
        }
        model_changes[attribute] = [
          folder_data[model_changes[attribute][0]],
          folder_data[model_changes[attribute][1]]
        ]
      when :visibility
        if model_changes[attribute][:access_type].present?
          access_type = Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TYPE
          access_type_changes = model_changes[attribute][:access_type]
          model_changes[:access_type] = [
            I18n.t("admin.audit_log.canned_response.#{access_type[access_type_changes[0]]}"),
            I18n.t("admin.audit_log.canned_response.#{access_type[access_type_changes[1]]}")
          ]
        end
        if model_changes[attribute][:groups].present?
          model_changes[:group_ids] = model_changes[attribute][:groups]
          model_changes[:group_ids][:added] = build_group_changes model_changes[attribute][:groups][:added]
          model_changes[:group_ids][:removed] = build_group_changes model_changes[attribute][:groups][:removed]
        end
      end
    end
    model_changes
  end
end

def build_group_changes(group_ids)
  return [] if group_ids.empty?

  @groups = Account.current.groups_from_cache.inject({}) { |hash, key| hash.merge!(key[:id] => key[:name]) }
  group_hash = []
  group_ids.each { |key| group_hash << { id: key, name: @groups[key] } }
  group_hash
end
