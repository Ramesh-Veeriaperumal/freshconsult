module UsersTestHelper
  def add_test_agent(account=nil, options={})
    account = account || @account

    role_id = options[:role].nil? ? account.roles.find_by_name("Account Administrator").id : options[:role]

    add_agent(account, {:name => Faker::Name.name,
                        :email => Faker::Internet.email,
                        :active => 1,
                        :role => 1,
                        :agent => 1,
                        :ticket_permission => 1,
                        :role_ids => ["#{role_id}"] })
  end

  def add_agent(account, options={})
    role_id = @account.roles.find_by_name("Agent").id
    new_agent = FactoryGirl.build(:agent,
                                  :account_id => account.id,
                                  :available => 1,
                                  :ticket_permission => options[:ticket_permission] || Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
    new_user = FactoryGirl.build(:user,
                                    :account_id => account.id,
                                    :name => options[:name] || Faker::Name.name,
                                    :email => options[:email] || Faker::Internet.email,
                                    :helpdesk_agent => options[:agent] || 1,
                                    :time_zone => options[:time_zone] || "Chennai",
                                    :active => options[:active] || 1,
                                    :user_role => options[:role] || role_id,
                                    :delta => 1,
                                    :language => "en",
                                    :role_ids => options[:role_ids] || ["#{role_id}"])
    new_user.agent = new_agent
    new_user.privileges = options[:privileges] || account.roles.find_by_id(role_id).privileges
    v = new_user.save!
    if options[:group_id]
      ag_grp = AgentGroup.new(:user_id => new_agent.user_id , :account_id =>  account.id, :group_id => options[:group_id])
      ag_grp.save!
    end
    new_user.reload
  end

  def add_new_user(account, options={})

    if options[:email]
      user = User.find_by_email(options[:email])
      return user if user
    end
    new_user = FactoryGirl.build(:user, :account => account,
                                    :name => options[:name] || Faker::Name.name,
                                    :email => options[:email] || Faker::Internet.email,
                                    :time_zone => options[:time_zone] || "Chennai",
                                    :delta => 1,
                                    :deleted => options[:deleted] || 0,
                                    :blocked => options[:blocked] || 0,
                                    :company_id => options[:customer_id] || nil,
                                    :language => "en")
    new_user.custom_field = options[:custom_fields] if options.key?(:custom_fields)
    new_user.save
    new_user.reload
  end
end