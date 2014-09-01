require 'spec_helper'

describe Agent do

  before (:all) do
  	@agent1 = add_agent_to_account(@account, {:name => "testing2", :email => Faker::Internet.email, 
                                              :active => 1, :role => 1
                                              })
  end

  it "should be available by default"  do
  	@agent2 = add_agent_to_account(@account, {:name => "testing3", :email => Faker::Internet.email, 
                                              :active => 1, :role => 1
                                              })
  	@agent2.available.should be_true
  end

  it "can be made unavailable" do
  	@agent1.available = 0
  	@agent1.save!
  	@agent1.available?.should == false
  end

end


