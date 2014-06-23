require 'spec_helper'

describe Integrations::IntegratedResourcesController do
  setup :activate_authlogic

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
  end

  before(:each) do
    log_in(@agent)
  end

  it "should create a new IntegratedResource" do

    post :create, {
      :integrated_resource => {
        :remote_integratable_id => "ROSH-100",
        :account => @account,
        :local_integratable_id => @test_ticket.id,
        :local_integratable_type => "issue-tracking"
      },
      :application_id => "10"
    }
  end

end