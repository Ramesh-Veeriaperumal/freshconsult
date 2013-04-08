#require '../spec_helper'
require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module AccountHelper

  def create_test_account(name = "test_account", domain = "test@freshdesk.local")
    @acc = Account.last
    return @acc unless @acc.nil?
    
    @email_config = Factory.build(:primary_email_config)
    @portal = Factory.build(:main_portal)
    
    @acc = Factory.build(:account, :primary_email_config => @email_config, :main_portal => @portal,
                         :name => name, :full_domain => domain)
    sub = Factory.build(:subscription, :subscription_plan => @acc.plan, :account => @acc)
    @user1 = Factory.build(:user, :account => @acc)
    @acc.user = @user1
    @acc.subscription = sub
    @acc.main_portal = @portal
    PortalObserver.any_instance.stubs(:after_save => true)
    create_dummy_customer
    @acc.save(false)
    @acc
  end

  def create_dummy_customer
    @customer = Factory.build(:user, :account => @acc, :email => "customer@customer.in",
                              :user_role => 3, :single_access_token => "blahblahblah")
    @customer.save(false)
    @acc.users << @customer
  end

  def clear_data
    Account.destroy_all
    User.destroy_all
    Group.destroy_all
    Agent.destroy_all
    Helpdesk::Ticket.destroy_all
    AgentGroup.destroy_all
  end

end

