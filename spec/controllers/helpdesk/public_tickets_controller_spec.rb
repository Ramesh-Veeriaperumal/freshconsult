require 'spec_helper'

describe Public::TicketsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false
  
  before(:all) do
    @test_ticket = create_ticket({ :status => 2 })
    @test_ticket.get_access_token
  end
  
  describe "If access token of a ticket is valid" do
    context "For logged in agents" do
      it "must redirect to helpdesk/ticket/:id page" do
        log_in(@agent)
        access_token  =  @test_ticket.access_token
        get :show, {:id => access_token }
        response.should redirect_to(helpdesk_ticket_path(@test_ticket))
      end
    end
    context "For not logged in agents" do
      it "must render show template" do
        access_token  =  @test_ticket.access_token
        get :show, {:id => access_token }
        response.body.should =~ /#{@test_ticket.description}/
        response.body.should =~ /#{access_token}/
        response.should render_template :show
      end
    end
    
    context "For users" do
      it "must render show template " do
        access_token  =  @test_ticket.access_token
        get :show, {:id => access_token }
        response.body.should =~ /#{@test_ticket.description}/
        response.body.should =~ /#{access_token}/
        response.should render_template :show
      end
    end 
  end
  
  
  describe "If access token of a ticket is invalid" do
    it "must redirect to access denied" do
      access_token_in_valid = rand(36**32).to_s(36)
      get :show, {:id => access_token_in_valid }
      response.should redirect_to(send(Helpdesk::ACCESS_DENIED_ROUTE))
    end
  end
end
