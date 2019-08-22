class MakeAgentValidation < ApiValidation
  attr_accessor :occasional, :role_ids, :group_ids, :signature, :ticket_scope, :type, :id

  validates :occasional, data_type: { rules: 'Boolean' }
  validates :role_ids, :ticket_scope, custom_absence: { message: :agent_roles_and_scope_error, code: :inaccessible_field }, if: -> { User.current.id == id }
  validates :signature, data_type: { rules: String, allow_nil: true }
  validates :ticket_scope, custom_inclusion: { in: AgentConstants::TICKET_SCOPES, detect_type: true }
  validates :group_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0 } }
  validates :role_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0 } }
  validates :type, custom_inclusion: { in: proc { |x| x.account_agent_types }, data_type: { rules: String } }
  validate :check_agent_limit, if: -> { occasional.blank? && type != Agent::FIELD_AGENT }
  validate :check_field_agent_limit, if: -> { type == Agent::FIELD_AGENT }
  validate :check_field_agent_groups, if: -> { type == Agent::FIELD_AGENT && group_ids.present? }

  def check_agent_limit
    agent_limit_reached, agent_limit = ApiUserHelper.agent_limit_reached?
    if agent_limit_reached
      errors[:occasional] = :max_agents_reached
      (error_options[:occasional] ||= {}).merge!(max_count: agent_limit, code: :incompatible_value)
    end
  end

  def check_field_agent_limit
    errors[:field_agent] = :max_field_agents_reached if Account.current.reached_field_agent_limit?
  end

  def check_field_agent_groups
    group_type_id = GroupType.group_type_id(GroupConstants::FIELD_GROUP_NAME)
    valid_groups = Account.current.groups_from_cache.select { |group| group.group_type == group_type_id }
    invalid_groups = group_ids - valid_groups.map(&:id)
    if invalid_groups.present?
      self.errors.add(:group_ids, ErrorConstants::ERROR_MESSAGES[:should_not_be_support_group])
    end
  end

  def account_agent_types
    Account.current.agent_types_from_cache.map(&:name)
  end
end
