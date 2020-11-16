class AgentType < ActiveRecord::Base
  # name, label, and agent_type_id
  # If we need to craete custom agent types, we need to offset agent_type_id to some higervalues, so that we can have our default types without collision.
  DEFAULT_AGENT_TYPE_LIST = {
    support_agent: [:support_agent, 'support_agent', 1],
    field_agent: [:field_agent, 'field_agent', 2],
    collaborator: [:collaborator, 'collaborator', 3]
  }

  # not meant to be used outside of this class. use agent_type_id instead
  DEFAULT_AGENT_TYPE_VS_AGENT_TYPE_ID = Hash[DEFAULT_AGENT_TYPE_LIST.values.map { |detail| [detail[0], detail[2]] }].freeze
  DEFAULT_AGENT_TYPE_ID_VS_AGENT_TYPE_NAME = Hash[DEFAULT_AGENT_TYPE_LIST.values.map { |detail| [detail[2], detail[0]] }].freeze
  private_constant :DEFAULT_AGENT_TYPE_VS_AGENT_TYPE_ID, :DEFAULT_AGENT_TYPE_LIST, :DEFAULT_AGENT_TYPE_ID_VS_AGENT_TYPE_NAME

  self.table_name = :agent_types
  self.primary_key = :id
  belongs_to_account

  validates_presence_of :name
  validates_uniqueness_of :name, scope: :account_id
  attr_accessible :name, :label, :default, :agent_type_id, :deleted
  after_commit :clear_agent_types_cache

  def self.agent_type_id(agent_type_name)

    return DEFAULT_AGENT_TYPE_VS_AGENT_TYPE_ID[agent_type_name.to_sym] if agent_type_name && DEFAULT_AGENT_TYPE_VS_AGENT_TYPE_ID.key?(agent_type_name.to_sym)

    agent_type = Account.current.agent_types_from_cache.find { |type| type.name == agent_type_name.to_s }
    agent_type ? agent_type.agent_type_id : nil
  end

  def self.agent_type_name(agent_type_id)

    return DEFAULT_AGENT_TYPE_ID_VS_AGENT_TYPE_NAME[agent_type_id].to_s if DEFAULT_AGENT_TYPE_ID_VS_AGENT_TYPE_NAME.key?(agent_type_id)

    agent_type = Account.current.agent_types_from_cache.find { |type| type.agent_type_id == agent_type_id }
    agent_type ? agent_type.name : nil
  end

  def self.create_agent_type(account, agent_type)
    agent_type = agent_type.to_sym
    agent_type_details = DEFAULT_AGENT_TYPE_LIST[agent_type]

    raise "Invalid agent type #{agent_type}" unless agent_type_details

    create_agent_type_with(agent_type_details, account)
  end

  # Temp method to directly create support agent type if it was created as part of fixtures/migration.
  def self.create_support_agent_type(account)
    agent_type_details = DEFAULT_AGENT_TYPE_LIST[:support_agent]
    create_agent_type_with(agent_type_details, account)
  end

  def self.destroy_agent_type(account, agent_type)
    agent_type = account.agent_types.find_by_name(agent_type.to_s)
    agent_type.destroy if agent_type
  end

  def clear_agent_types_cache
    Account.current.clear_agent_types_cache
  end

  def self.create_agent_type_with(agent_type_details, account)
    agent_type = Account.current.agent_types.find_by_name(agent_type_details[0])
    return agent_type if agent_type

    agent_type = account.agent_types.create(
      name: agent_type_details[0],
      label: agent_type_details[1],
      account_id: account.id,
      deleted: false,
      default: true,
      agent_type_id: agent_type_details[2]
    )
    agent_type.save!
    agent_type
  rescue Exception => e # rubocop:disable RescueException
    error_message = "Agent type creation failed for account:: #{account.id}. Agent type: #{agent_type_details.join(', ')} Exception:: #{e.message} \n#{e.backtrace.to_a.join("\n")}"
    Rails.logger.error(error_message)
    NewRelic::Agent.notice_error(error_message)
  end
  private_class_method :create_agent_type_with
end
