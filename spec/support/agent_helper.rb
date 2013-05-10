require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module AgentHelper

def add_agent_to_account(account, options={})
  available = options[:available] || 1
  new_agent = Factory.build(:agent, :signature => "Regards, #{options[:name]}", 
                                  :account_id => account.id, :available => available)

  new_user = Factory.build(:user, :account => account,
                    :name => options[:name], :email => options[:email],
                    :time_zone => "Chennai", :single_access_token => options[:token],
                    :active => options[:active], :user_role => options[:role], :delta => 1, :language => "en") 
  new_user.agent = new_agent

  new_user.save(false)
  
  if options[:group_id]
    ag_grp = AgentGroup.new(:user_id => new_agent.user_id , :account_id =>  account.id, :group_id => options[:group_id])
    ag_grp.save!
  end
  @acc.users << new_user

  return new_agent
  
  end

end