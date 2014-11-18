require 'spec_helper'

describe Integrations::IntegratedResourcesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
    new_application = FactoryGirl.build(:application, :name => "pivotal_tracker",
                                    :display_name => "pivotal_tracker",
                                    :listing_order => 23,
                                    :options => {
                                        :keys_order => [:api_key, :pivotal_update],
                                        :api_key => { :type => :text, :required => true, :label => "integrations.pivotal_tracker.api_key", :info => "integrations.pivotal_tracker.api_key_info"},
                                        :pivotal_update => { :type => :checkbox, :label => "integrations.pivotal_tracker.pivotal_updates"}
                                    },
                                    :application_type => "pivotal_tracker")
    new_application.save(:validate => false)

    new_installed_application = FactoryGirl.build(:installed_application, :application_id => "23",
                                              :account_id => @account.id,
                                              :configs => { :inputs => { 'api_key' => "c599b57edad0cb430d6fbf2543450c6c", "pivotal_update" => "1"} }
                                              )
    @new_installed = new_installed_application.save(:validate => false)
    integrated_res = FactoryGirl.build(:integrated_resource, :installed_application_id => new_installed_application.id,
                    :remote_integratable_id => "1106038/stories/73687832", :local_integratable_id => @test_ticket.id,
                    :local_integratable_type => "issue-tracking", :account_id => @account.id)
    resp = integrated_res.save!
  end

  before(:each) do
    log_in(@agent)
  end

  it "should create a new IntegratedResource" do

    post :create, {
      :integrated_resource => {
        :remote_integratable_id => "ROSH-100",
        :account => @account,
        :local_integratable_id => @test_ticket.display_id,
        :local_integratable_type => "issue-tracking"
      },
      :application_id => "10"
    }
    response.status.should eql 200
  end

  it "should fail create for a new IntegratedResource" do
    Integrations::IntegratedResource.any_instance.stubs(:save!).raises(StandardError)     
    post :create, {
        :integrated_resource => {
        :error => "test_error"
        }
    }
    response.status.should eql 200
  end

  it "should fail for delete integrated resource" do
    Integrations::IntegratedResource.any_instance.stubs(:delete).raises(Timeout::Error)      
    id = Integrations::IntegratedResource.find_by_remote_integratable_id("1106038/stories/73687832").id
    delete :delete, { :integrated_resource => { :id => id, :remote_integratable_id => "1106038/stories/73687832", :account => @account}}
    response.status.should eql 200
  end


  it "should delete integrated resource" do 
    id = Integrations::IntegratedResource.find_by_remote_integratable_id("1106038/stories/73687832").id
    delete :delete, { :integrated_resource => { :id => id, :remote_integratable_id => "1106038/stories/73687832", :account => @account}}
    response.status.should eql 200
  end
  
  it "should fail for delete integrated resource" do
    Integrations::IntegratedResource.any_instance.stubs(:deleteResource).raises(Timeout::Error)      
    delete :delete, { :integrated_resource => {:integrated_resource => {
        :error => "test_error"
        }}}
    response.status.should eql 200
  end

end