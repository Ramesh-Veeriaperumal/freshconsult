class Admin::Groups::AgentsDelegator < BaseDelegator
  attr_accessor :agents, :group
  validate :agent_data_user_ids_validation, if: -> { validation_context == :update }

  def initialize(record, options = {})
    @group = record
    @agents = options[:agents]
    super(record, options)
  end

  def agent_data_user_ids_validation
    technicians_user_ids = Account.current.agents_hash_from_cache.keys
    request_user_ids = agents.map { |agent_hash| agent_hash[:id] }
    invalid_user_ids = request_user_ids - technicians_user_ids
    if invalid_user_ids.present?
      errors[:invalid_agent_ids] << :invalid_list
      error_options[:invalid_agent_ids] = { list: invalid_user_ids.join(', ') }
    end
  end
end
