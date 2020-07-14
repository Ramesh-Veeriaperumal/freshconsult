module AgentHelper

  def add_agent_to_account(account, options={})
    old_subscription_state = account.subscription.state
    account.subscription.state = 'trial'
    account.subscription.save
    available = options[:available] || 1
    time_zone = options[:time_zone] || "Chennai"
    options[:email] = options[:email] || Faker::Internet.email
    new_agent = FactoryGirl.build(:agent, :signature => "Regards, #{options[:name]}", 
                                      :account_id => account.id, 
                                      :available => available)
    new_user = FactoryGirl.build(:user, :account_id => account.id,
                                    :name => options[:name], 
                                    :email => options[:email],
                                    :time_zone => time_zone, 
                                    :single_access_token => Faker::Lorem.characters(20), 
                                    :helpdesk_agent => true, 
                                    :active => options[:active], 
                                    :user_role => options[:role], 
                                    :delta => 1, 
                                    :language => options[:language] || "en")  
    new_user.agent = new_agent
    new_user.roles = [account.roles.second]
    new_user.save_without_session_maintenance
    new_user.reload
    
    if options[:group_id]
      ag_grp = AgentGroup.new(:user_id => new_agent.user_id , 
                              :account_id =>  account.id, 
                              :group_id => options[:group_id])
      ag_grp.save!
    end
    account.users << new_user
    new_agent
  ensure
    account.subscription.state = old_subscription_state
    account.subscription.save
  end
end
