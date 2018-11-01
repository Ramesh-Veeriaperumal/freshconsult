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

  def event_info action
    { :ip_address => Thread.current[:current_ip] }
  end

  def model_changes_for_central
    self.previous_changes
  end

  def relationship_with_account
    "account_va_rules"
  end
end
