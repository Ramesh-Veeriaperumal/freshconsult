require 'spec_helper'

include Gamification::Quests::Constants

RSpec.describe Admin::QuestsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    quest_data = {:value=>"4", :date=>"4"}
    @new_quest = create_article_quest(@account, quest_data)

    flexifield_def_entry = FactoryGirl.build(:flexifield_def_entry, 
                                         :flexifield_def_id => @account.flexi_field_defs.find_by_name("Ticket_#{@account.id}").id,
                                         :flexifield_alias => "tkt_level_#{@account.id}",
                                         :flexifield_name => "ff_int01",
                                         :flexifield_coltype => "number",
                                         :account_id => @account.id)
    flexifield_def_entry.save
    custom_field = FactoryGirl.build( :ticket_field, :account_id => @account.id,
                                                 :name => "tkt_level_#{@account.id}",
                                                 :field_type => "custom_number",
                                                 :flexifield_def_entry_id => flexifield_def_entry.id)
    custom_field.save
  end

  before(:each) do
    login_admin
  end

  it "should display the quest index page" do
    get :index
    response.body.should =~ /redirected/
    response.should redirect_to("/admin/gamification#quests")
  end

  it "should render new quest" do
    get :new
    response.body.should =~ /New Quest/
    response.body.should =~ /Quest type/
    response.should be_success
  end

  it "should create new quest" do
    quest_data = [{ :value => "3",:date => "2" }].to_json  
    post :create, { :quest =>{ :category=> GAME_TYPE_KEYS_BY_TOKEN[:ticket], :badge_id=>"45", :points=>"70", :name=>"Quicker man!", 
                               :description=>"Resolve 3 tickets in a span of 1 day and matching these conditions.On successful completion of the quest you can unlock Minute-man badge and 70 bonus points."
                              },
                    :quest_data_date=>"2", :filter_data=>"", :quest_data=> quest_data
    }
    session[:flash][:notice].should eql "The quest has been created."  
    quest = @account.quests.find_by_badge_id(45)
    quest.should be_an_instance_of(Quest)
    response.should redirect_to "/admin/gamification#quests"
  end

  it "should not create new quest without quest_name" do
    before_count = @account.quests.count
    quest_data = [{ :value => "34",:date => "3" }].to_json  
    post :create, { :quest =>{ :category=> GAME_TYPE_KEYS_BY_TOKEN[:ticket], :badge_id=>"1", :points=>"90", :name=>"", 
                               :description=>"Resolve 34 tickets in a span of 2 day and matching these conditions.On successful completion of the quest you can unlock Minute-man badge and 70 bonus points."
                              },
                    :quest_data_date=>"3", :filter_data=>"", :quest_data=> quest_data
    }
    response.body.should =~ /New Quest/
    @account.reload
    after_count = @account.quests.count
    before_count.should eql after_count
    response.should be_success
  end

  it "should edit the quest" do
    get :edit, :id => @new_quest.id
    response.body.should =~ /#{@new_quest.name}/
    response.body.should =~ /#{@new_quest.points}/
    response.should be_success
  end

  it "should update the quest" do
    quest_data = [{ :value => "7",:date => "5" }].to_json
    put :update, { :id => @new_quest.id,
                   :quest=>{:category=> GAME_TYPE_KEYS_BY_TOKEN[:solution], :badge_id=>"41", :points=>"250", :name=>"Customer's Article man!", 
                            :description=>"Create 7 knowledge base article in a span of 2 week and matching these conditions.On successful completion of the quest you can unlock Flag bearer badge and 340 bonus points."
                            }, 
                   :quest_data_date=>"5", :filter_data=>"", :filter=>"end", :name=>"-1", :quest_data=> quest_data
    }
    response.body.should =~ /redirected/
    @new_quest.reload
    @new_quest.name.should eql "Customer's Article man!"
    @new_quest.points.should eql(250)
    @new_quest.quest_data.first[:value].should eql "7"
    @new_quest.quest_data.first[:date].should eql "5"
  end

  it "should not update the quest without badge_id" do
    quest_data = [{ :value => "10",:date => "5" }].to_json
    put :update, { :id => @new_quest.id,
                   :quest=>{:category=> GAME_TYPE_KEYS_BY_TOKEN[:solution], :badge_id=>"", :points=>"250", :name=>"Article man!", 
                            :description=>"Create 10 knowledge base article in a span of 2 week and matching these conditions.On successful completion of the quest you can unlock Flag bearer badge and 340 bonus points."
                            }, 
                   :quest_data_date=>"5", :filter_data=>"", :filter=>"end", :name=>"-1", :quest_data=> quest_data
    }
    response.body.should_not =~ /redirected/
    @new_quest.reload
    response.body.should =~ /Please select a badge./
    @new_quest.name.should_not eql "Article man!"
    @new_quest.name.should eql "Customer's Article man!"
    @new_quest.quest_data.first[:value].should_not eql "10"
    @new_quest.quest_data.first[:value].should eql "7"
  end

  it "should inactivate the quest" do
    @new_quest.active = true
    @new_quest.save
    put :toggle, :id => @new_quest.id
    @new_quest.reload
    @new_quest.active.should be_falsey
  end

  it "should activate the quest" do
    @new_quest.active = false
    @new_quest.save
    put :toggle, :id => @new_quest.id
    @new_quest.reload
    @new_quest.active.should be_truthy
  end
end