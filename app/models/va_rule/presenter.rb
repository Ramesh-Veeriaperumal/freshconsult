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
    v.add :condition_data
    v.add :filtered_action_data, as: :action_data
    v.add :last_updated_by
    v.add :outdated
    v.add :account_id
    v.add :rule_type
    v.add :active
    v.add :position
    DATETIME_FIELDS.each do |key|
      v.add proc { |x| x.utc_format(x.send(key)) }, as: key
    end
  end

  def filtered_action_data
    hide_sensitive_info(action_data)
  end

  def central_payload_type
    action = [:create, :update, :destroy].find{ |action| transaction_include_action? action }
    "#{VAConfig::RULES_BY_ID[self.rule_type].to_s}_#{action}"
  end

  def event_info action
    { :ip_address => Thread.current[:current_ip] }
  end

  def model_changes_for_central
    changes = self.previous_changes
    if changes.has_key?("action_data")
      changes["action_data"].each do |actions|
        hide_sensitive_info(actions)
      end
    elsif changes.has_key?('position') && self.frontend_positions.present?
      changes[:position] = self.frontend_positions # position from ui perspective
    end
    changes
  end

  def relationship_with_account
    "account_va_rules"
  end

  def hide_sensitive_info(actions)
    action = actions.select { |action| action[:name] == "trigger_webhook" }.first
    if action.present?
      action[:password] = "*" if action.key?(:password)
      action[:api_key] = "*" if action.key?(:api_key)
    end
    actions
  end
end
