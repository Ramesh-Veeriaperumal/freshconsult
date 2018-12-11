class AgentType < ActiveRecord::Base
  DEFAULT_AGENT_TYPE_LIST = {
    support_agent: [:support_agent, 'support_agent'],
    field_agent: [:field_agent, 'field_agent']
  }
  self.table_name = :agent_types
  self.primary_key = :id
  belongs_to_account

  validates_presence_of :name
  validates_uniqueness_of :name, scope: :account_id
  attr_accessible :name, :label, :default, :agent_type_id, :deleted
  after_commit :clear_agent_types_cache

  def self.agent_type_id(agent_type_name)
    agent_type = Account.current.agent_types_from_cache.find { |type| type.name == agent_type_name }
    agent_type ? agent_type.agent_type_id : nil
  end

  def self.agent_type_name(agent_type_id)
    agent_type = Account.current.agent_types_from_cache.find { |type| type.agent_type_id == agent_type_id }
    agent_type ? agent_type.name : nil
  end

  #Determines ID to be used for a new agent type
  def self.next_agent_type_id
    agent_types = Account.current.agent_types_from_cache 
    agent_types.length > 0 ? agent_types.max_by(&:agent_type_id).agent_type_id + 1 : 1
  end

  def self.create_agent_type(account, agent_type)
    agent_type = agent_type.to_sym
    agent_type_details = DEFAULT_AGENT_TYPE_LIST[agent_type]
    agent_type_id = self.next_agent_type_id
    raise "Invalid agent type #{agent_type}" unless agent_type_details
    self.create_agent_type_with(agent_type_details, account , agent_type_id)
  end

  #Temp method to directly create support agent type if it was created as part of fixtures/migration.
  def self.create_support_agent_type(account)
    agent_type_details = DEFAULT_AGENT_TYPE_LIST[:support_agent]
    self.create_agent_type_with(agent_type_details, account, 1)
  end

  def self.create_agent_type_with(agent_type_details, account, agent_type_id)
    begin
      agent_type = account.agent_types.create(name: agent_type_details[0],
                                            label: agent_type_details[1],
                                            account_id: account.id,
                                            deleted: false,
                                            default: true,
                                            agent_type_id: agent_type_id)
      agent_type.save!
      agent_type
    rescue Exception => e
      error_message = "Agent type creation failed for account:: #{account.id}. Agent type: #{agent_type_details.join(", ")} Exception:: #{e.message} \n#{e.backtrace.to_a.join("\n")}"
      Rails.logger.error(error_message)
      NewRelic::Agent.notice_error(error_message)
    end
  end

  def self.destroy_agent_type(account, agent_type)
    agent_type = account.agent_types.find_by_name(agent_type.to_s)
    agent_type.destroy if agent_type   
  end

  def clear_agent_types_cache
    Account.current.clear_agent_types_cache
  end
end
