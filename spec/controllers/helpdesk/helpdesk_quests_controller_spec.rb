require 'spec_helper'

describe Helpdesk::QuestsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @all_quests = @account.quests.all(:limit => 25)
  end

  before(:each) do
    log_in(@agent)
  end

  it "should display the quest index page" do
    xhr :get, :index
    @all_quests.each do |quest|
      response.body.should =~ /#{quest.name}/
    end
    response.should be_success
  end

  it "should display the active quests" do
    get :active
    response.body.should =~ /Available Quests/
    response.should be_success
  end

  it "should display the unachieved quests" do
    quest = @account.quests.find_by_name(@all_quests[0].name)
    achieved_quest = Factory.build(:achieved_quest, :user_id => @agent.id, :account_id => @account.id, :quest_id => quest.id)
    achieved_quest.save(false)
    xhr :get, :unachieved
    response.body.should_not =~ /#{quest.name}/
    response.should be_success
  end
end