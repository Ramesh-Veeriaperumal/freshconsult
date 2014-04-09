require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module UsersHelper
  def add_test_agent(account)
    add_agent(account, {:name => Faker::Name.name, 
                        :email => Faker::Internet.email, 
                        :active => 1, 
                        :role => 1, 
                        :agent => 1,
                        :ticket_permission => 1,
                        :role_ids => ["#{account.roles.find_by_name("Account Administrator").id}"] })
  end

  def add_agent(account, options={})
    new_agent = Factory.build(:agent, :account => account, 
                                      :available => 1, 
                                      :ticket_permission => options[:ticket_permission])
    new_user = Factory.build(:user, :account => account,
                                    :name => options[:name], 
                                    :email => options[:email], 
                                    :helpdesk_agent => options[:agent],
                                    :time_zone => "Chennai", 
                                    :active => options[:active], 
                                    :user_role => options[:role], 
                                    :delta => 1, 
                                    :language => "en",
                                    :role_ids => options[:role_ids])
    new_user.agent = new_agent
    new_user.privileges = options[:privileges] || account.roles.find_by_name("Account Administrator").privileges
    new_user.save(false)
    new_user
  end

  def add_new_user(account, options={})
    new_user = Factory.build(:user, :account => account,
                                    :name => Faker::Name.name, 
                                    :time_zone => "Chennai", 
                                    :delta => 1, 
                                    :language => "en")
    new_user.save(false)
    new_user
  end
end