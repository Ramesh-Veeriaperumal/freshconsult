require 'spec_helper'

describe ContactMergeController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user1 = add_new_user(@account)
  end

  before(:each) do
    log_in(@agent)
  end

  it "should not merge for agent" do
    post :new, :id => @agent.id
    response.body.should =~ /The change you wanted was rejected/
  end

end
