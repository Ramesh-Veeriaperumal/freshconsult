require 'spec_helper'

describe Integrations::IntegratedResourcesController do
setup :activate_authlogic

before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
end

 before(:each) do
    @request.host = @account.full_domain
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                        (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    log_in(@user)
  end



it "should create a new IntegratedResource" do

	post :create, {:integrated_resource => {
           							:remote_integratable_id => "ROSH-100",
           							:account => @account,
           							:local_integratable_id => @test_ticket.id,
            						:local_integratable_type => "issue-tracking"
            					},
            					:application_id => "10"

            				}
            						
           							


end



end
