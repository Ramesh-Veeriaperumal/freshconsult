require 'spec_helper'

describe Freshfone::CallerController do

  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    @request.host = @account.full_domain
    log_in(@agent)
    create_test_freshfone_account
    create_freshfone_caller
    @request.env["HTTP_ACCEPT"] = "text/javascript"
  end

  it "should block the caller" do
    post :block , {:caller =>{:id => @caller.id } }
    expect(response.status).to eql(200)
    expect(flash[:notice]).to eql("Number blocked successfully")
  end

  it "should not block the caller if not able to save" do
    Freshfone::Caller.any_instance.stubs(:save) { false }
    post :block , {:caller =>{:id => @caller.id } }
    expect(response.status).to eql(200)
    expect(flash[:notice]).to eql("Number could not be blocked")
    Freshfone::Caller.any_instance.unstub(:save)
  end

  it "should unblock the caller" do
    @caller.update_attributes({:caller_type => 1})
    @caller.reload
    post :unblock , {:caller =>{:id => @caller.id } }
    expect(response.status).to eql(200)
    expect(flash[:notice]).to eql("Number unblocked successfully")
  end

it "should not unblock the caller if not able to save" do
    @caller.update_attributes({:caller_type => 1})
    @caller.reload
    Freshfone::Caller.any_instance.stubs(:save) { false }
    post :unblock , {:caller =>{:id => @caller.id } }
    expect(response.status).to eql(200)
    expect(flash[:notice]).to eql("Number could not be unblocked")
    Freshfone::Caller.any_instance.unstub(:save)
  end

end
