account = Account.current
AgentType.create_support_agent_type(account) unless account.agent_types.length > 0
