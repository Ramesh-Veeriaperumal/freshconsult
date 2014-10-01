require 'spec_helper'

describe Helpdesk::QuestsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @quest = all_quests[0]
    @quest.name = "Ideal supporter"
    @quest.save(:validate => false)
  end

  before(:each) do
    log_in(@agent)
  end

  it "should display the quest index page" do
    xhr :get, :index
    all_quests.each do |quest|
      response.body.should =~ /#{ERB::Util.html_escape(quest.name)}/
    end
    response.should be_success
  end

  it "should display the active quests" do
    get :active
    response.body.should =~ /Available Quests/
    2.times do |x|
      response.body.should =~ /#{ERB::Util.html_escape(all_quests[x].name)}/
    end
    response.should be_success
  end

  it "should display the unachieved quests" do
    achieved_quest = FactoryGirl.build(:achieved_quest, :user_id => @agent.id, :account_id => @account.id, :quest_id => @quest.id)
    achieved_quest.save(:validate => false)
    xhr :get, :unachieved
    response.body.should_not =~ /#{@quest.name}/
    response.should be_success
  end

    def all_quests
      @account.quests.available(@agent).all(:limit => 25)
    end
end