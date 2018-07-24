class VaRule < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at]

  acts_as_api

  api_accessible :central_publish do |v|
    v.add :id
    v.add :name
    v.add :description
    v.add :match_type
    v.add :filter_data
    v.add :action_data
    v.add :account_id
    v.add :rule_type
    v.add :active
    v.add :position
    DATETIME_FIELDS.each do |key|
      v.add proc { |x| x.utc_format(x.send(key)) }, as: key
    end
  end

  def central_payload_type
    action = [:create, :update, :destroy].find{ |action| transaction_include_action? action }
    "#{VAConfig::RULES_BY_ID[self.rule_type].to_s}_#{action}"
  end

  def self.central_publish_enabled?
    Account.current.audit_logs_central_publish_enabled?
  end

  def event_info action
    { :ip_address => Thread.current[:current_ip] }
  end

  def model_changes_for_central
    self.previous_changes
  end

  def readable_model_changes(model_changes)
    model_changes.keys.each do |attribute|
      case attribute
      when "filter_data"
        if dispatchr_rule? || supervisor_rule? 
          translate_filter_action(model_changes[attribute], "CONDITIONS")
        elsif observer_rule?
          translate_observer_events(model_changes[attribute])
        end
      when "action_data"
        translate_filter_action(model_changes[attribute], "ACTIONS")
      when "active"
        model_changes[attribute] = [
          AuditLogConstants::TOGGLE_ACTIONS[model_changes[attribute][0]],
          AuditLogConstants::TOGGLE_ACTIONS[model_changes[attribute][1]]
        ]
      end
    end
    model_changes
  end

  def translate_observer_events(model_changes)
    ["events", "performer", "conditions"].each do |key|
      case key
      when "events"
        translate_filter_action([model_changes[0][key], model_changes[1][key]], "EVENTS")
      when "performer"
        model_changes.each do |changes|
          changes[key]["type"] = Va::Performer::TYPE_CHECK[changes[key]["type"]][:english_key]
          if changes[key].key?("members")
            changes[key]["members"] = Account.current.agents_from_cache.select { |agent| 
              changes[key]["members"].include? agent.user_id.to_s }.map(&:name)
          end
        end
      when "conditions"
        translate_filter_action([model_changes[0][key], model_changes[1][key]], "CONDITIONS")
      end
    end
  end

  def translate_filter_action(model_changes, type)
    model_changes.each do |actions|
      actions.each do |action|
        name_key = (action.key?("evaluate_on") && action["evaluate_on"] != "ticket") ? 
                    "#{action["evaluate_on"]}_#{action["name"]}" :
                    action["name"]
        name_key = "created_at_supervisor" if supervisor_rule? && name_key == "created_at"
        readable = Va::Constants.const_get("READABLE_#{type}")[name_key]
        readable_name = readable.present? ? readable[0] : 
                          custom_field_name(action["name"], action["evaluate_on"])
        action["name"] = readable_name if readable_name.present?
        action["operator"] = action["operator"].gsub("_", " ") if action.key?("operator")

        if readable.present? && readable.length > 1
          ["value", "from", "to"].each do |key|
            next unless action.key?(key)
            if action[key] == "--"
              action[key] = "Any"
              next
            end
            if action[key] == ""
              action[key] = "None"
              next
            end
            if readable[1].is_a?(Hash)
              action[key] = action[key].is_a?(String) ? readable[1][action[key]] :
                              action[key].map { |val| readable[1][val] }.join(", ")
              next
            end
            actionable = Account.current.safe_send(readable[1]).
                          safe_send("find_all_by_#{readable[2]}", action[key])
            readable_value = actionable.present? ? actionable.map { |act| 
              act.respond_to?(:name) ? act.name : act.value }.join(", ") : ""
            action[key] = readable_value
          end
        end
      end
    end
  end

  def custom_field_name(name, evaluate_on)
    evaluate_on ||= "ticket"
    case evaluate_on
    when "requester"
      @custom_requester_fields ||= Account.current.contact_form.custom_fields
    when "company"
      @custom_company_fields ||= Account.current.company_form.custom_fields
    when "ticket"
      @custom_ticket_fields ||= Account.current.ticket_fields_from_cache
    end
    fields = instance_variable_get("@custom_#{evaluate_on}_fields")
    if fields.present?
      field = fields.find { |field| field.name == name }
      field.label if field.present?
    end
  end

  def relationship_with_account
    "account_va_rules"
  end
end
