#require '../spec_helper'
require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module AccountHelper

  def create_test_account(name = "test_account", domain = "test@freshdesk.local")
    @acc = Account.last
    unless @acc.nil?
      @acc.make_current
      create_dummy_customer
      return @acc
    end
    # ENV["SEED"]="002_subscription_plans"
    # SeedFu::PopulateSeed.populate
    # ENV["SEED"] = nil
    # signup = Signup.new(  
    #   :account_name => 'Test Account',
    #   :account_domain => 'localhost',
    #   :locale => I18n.default_locale,
    #   :user_name => 'Support',
    #   :user_password => 'test',
    #   :user_password_confirmation => 'test',
    #   :user_email => Helpdesk::EMAIL[:sample_email],
    #   :user_helpdesk_agent => true
    # )
    # signup.save
    # @acc = signup.account
    # @acc.make_current
    # create_dummy_customer
    # @acc
    fail "No account in db. Ending tests..."
  end

  def create_dummy_customer
    @customer = User.find_by_email("customer@customer.in")
    return unless @customer.nil?
    @customer = Factory.build(:user, :account => @acc, :email => "customer@customer.in",
                              :user_role => 3)
    @customer.save
    @acc.users << @customer
  end

  def clear_data
    #Account.destroy_all
    User.destroy_all
    Group.destroy_all
    Agent.destroy_all
    Helpdesk::Ticket.destroy_all
    AgentGroup.destroy_all
    Solution::Category.destroy_all
    Solution::Folder.destroy_all  
    Solution::Article.destroy_all  
  end

end
