require 'spec_helper'

describe Helpdesk::AutocompleteController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    log_in(@agent)
    request.env["HTTP_ACCEPT"] = 'application/json'
  end

  it "should return the requesters matching the initial text" do
    user = add_new_user(@account)
    post :requester, :q => user.name
    result = JSON.parse(response.body)["results"]
    result.should be_an_instance_of(Array)
    result.first["id"].should be_eql(user.id)
    result.first["value"].should be_eql(user.name)
  end

  it "should return the companies matching the initial text" do
    company = create_company
    post :company, :q => company.name
    result = JSON.parse(response.body)["results"]
    result.should be_an_instance_of(Array)
    result.first["id"].should be_eql(company.id)
    result.first["value"].should be_eql(company.name)
  end
end