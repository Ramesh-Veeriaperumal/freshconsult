module PasswordPolicesSandboxHelper


  def password_policies_data(account)
    update_password_policies_data(account)
  end

  def update_password_policies_data(account)
    password_policies_data = []

    # Need to check for serialize columns
    contact_password_policy = account.contact_password_policy
    if contact_password_policy
      account.contact_password_policy.configs["minimum_characters"] =
      data = contact_password_policy.changes.clone
      contact_password_policy.save
      password_policies_data << [Hash[data.map { |k, v| [k, v[1]] }].merge({"id" =>contact_password_policy.id, "action" => 'modified', "model" => contact_password_policy.class.name })]
    end
    agent_password_policy = account.agent_password_policy
    if agent_password_policy
      account.agent_password_policy.configs["minimum_characters"] +=1
      data = agent_password_policy.changes.clone
      agent_password_policy.save
      password_policies_data << [Hash[data.map { |k, v| [k, v[1]] }].merge({"id" =>agent_password_policy.id, "action" => 'modified', "model" => agent_password_policy.class.name })]
    end
    password_policies_data.flatten
  end
end