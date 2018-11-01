module GroupHelper
	def create_group(account, options= {})
    group = account.groups.find_by_name(options[:name])
    return group if group
    name = options[:name] || Faker::Name.name
		group = FactoryGirl.build(:group,:name=> name)
		group.account_id = account.id
		group.ticket_assign_type  = options[:ticket_assign_type] if options[:ticket_assign_type]
        group.toggle_availability = options[:toggle_availability] if options[:toggle_availability]
		group.save!
		group
	end

  def create_group_with_agents(account, options= {})
    group = account.groups.find_by_name(options[:name])
    return group if group
    name = options[:name] || Faker::Name.name
    group = FactoryGirl.build(:group,:name=> name)
    group.account_id = account.id
    group.ticket_assign_type = options[:ticket_assign_type] if options[:ticket_assign_type]
    options[:agent_list].each { |agent| group.agent_groups.build(:user_id =>agent) } unless options[:agent_list].blank?
    group.save!
    group
  end

  def create_groups(account, options= {:count => 2})
    groups = []
    options[:count].times do |no|
        group = create_group(account)
        groups << group
    end
    groups
  end

  def create_group_private_api(account,options={})
    name = Faker::Name.name
    group = FactoryGirl.build(:group,:name=> name)
    group.account_id = account.id
    group.description=Faker::Lorem.paragraph   
    group.escalate_to=1
    group.agent_ids=[1,2]  
    group.business_calendar_id=1
    group.ticket_assign_type=options[:ticket_assign_type] if options[:ticket_assign_type]
    group.ticket_assign_type=options[:round_robin_type] if options[:round_robin_type]
    group.capping_limit=options[:capping_limit] if options[:capping_limit]  
    group.save!
    group
  end 

end
