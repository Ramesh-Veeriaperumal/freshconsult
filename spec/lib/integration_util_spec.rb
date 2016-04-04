require 'spec_helper'

RSpec.describe Integrations::Util do
  include Integrations::Util
 before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
   @app_id = Integrations::Application.find_by_name("pivotal_tracker")

    new_installed_application = FactoryGirl.build(:installed_application, :application_id => @app_id.id,
                                              :account_id => @account.id,
                                              :configs => {:inputs=>{"api_key"=>"c599b57edad0cb430d6fbf2543450c6c", "pivotal_update"=>"1", "webhooks_applicationid"=>["1106038"]}}
                                              )
    @new_installed = new_installed_application.save(:validate => false)
    integrated_res = FactoryGirl.build(:integrated_resource, :installed_application_id => new_installed_application.id,
                    :remote_integratable_id => "1106038/stories/73687832", :local_integratable_id => @test_ticket.display_id,
                    :local_integratable_type => "issue-tracking", :account_id => @account.id)
    resp = integrated_res.save!
    @response = { :pivotal_message => "success"}
  end

  it 'should split resource' do
  	resource = Integrations::IntegratedResource.all
  	app = Integrations::InstalledApplication.find_by_application_id(@app_id)
    pivotal_tracker_split_resource(resource,app)
    resource.should_not be_nil
  end

end