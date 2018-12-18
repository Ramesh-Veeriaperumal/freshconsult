module SharedOwnershipTestHelper
  def create_group(account, options = {})
    group = account.groups.find_by_name(options[:name])
    return group if group
    name = options[:name] || Faker::Name.name
    group = FactoryGirl.build(:group, name: name)
    group.account_id = account.id
    group.group_type = options[:group_type] if options[:group_type]
    group.ticket_assign_type  = options[:ticket_assign_type] if options[:ticket_assign_type]
    group.toggle_availability = options[:toggle_availability] if options[:toggle_availability]
    group.save!
    group
  end

  def create_internal_group
    create_group(@account, name: "Shared ownership group-#{Time.zone.now}")
  end

  def add_agent_to_group(group_id, ticket_permission, role_id)
    add_agent(@account, name: Faker::Name.name,
                        email: Faker::Internet.email,
                        active: 1,
                        role: 1,
                        agent: 1,
                        ticket_permission: ticket_permission,
                        role_ids: [role_id.to_s],
                        group_id: group_id)
  end

  def initialize_internal_agent_with_default_internal_group(permission = 3)
    @internal_group = @account.groups.first
    @status = @account.ticket_statuses.visible.where(is_default: false).first
    @status.group_ids = [@internal_group.id]
    @status.save
    @account.instance_variable_set(:@account_status_groups_from_cache, nil)
    @responding_agent = add_agent_to_group(nil,
                                           permission, role_id = @account.roles.agent.first.id)
    @internal_agent = add_agent_to_group(group_id = @internal_group.id,
                                         permission, role_id = @account.roles.agent.first.id)
  end

  def add_another_group_to_status
    @another_internal_group = @account.groups.second
    @status.group_ids = [@another_internal_group.id]
    @status.save
    @account.instance_variable_set(:@account_status_groups_from_cache, nil)
  end

  def add_agent_to_new_group
    @another_internal_group.agent_groups.build(user_id: @internal_agent.id)
    @another_internal_group.save
  end

  def initialize_internal_agent_with_custom_internal_group
    @internal_group = create_internal_group
    @status = @account.ticket_statuses.visible.where(is_default: 0).first
    @status.group_ids = [@internal_group.id]
    @status.save
    @internal_agent = add_agent_to_group(group_id = @internal_group.id, ticket_permission = 3,
                                         role_id = @account.roles.first.id)
    @account.instance_variable_set(:@account_status_groups_from_cache, nil)
  end
end
