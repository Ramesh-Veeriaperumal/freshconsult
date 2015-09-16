require 'spec_helper'
RSpec.configure do |c|
  c.include MemcacheKeys
end

RSpec.describe Admin::Integrations::FreshplugsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  it "renders the new application template" do
    get 'new'
    response.should render_template "admin/integrations/freshplugs/new"
  end

  it "should create a new application" do
    post :create, :application => {
                                   :display_name => "New Test application",
                                   :description => "New Test application subject",
                                   :script => "<div id='sample_highrise_widget' title='Sample CRM FreshPlug'>{{ticket.requester}}</div>",
                                   :view_pages => ["helpdesk_tickets_show_page_side_bar"]
                                  }
    response.should redirect_to "/integrations/applications#fresh-plugs"
  end

  it "renders the edit template of the application" do
    application = Integrations::Application.find_by_display_name("New Test application")
    get 'edit', :id => application.id
    response.should render_template "admin/integrations/freshplugs/edit"
  end

  it "should update an application" do
    application = Integrations::Application.find_by_display_name("New Test application")
    put :update,  { :id => application.id,
                    :application => 
                      {
                       :display_name => "New Test application",
                       :description => "New Test application subject",
                       :script => "<div id='sample_highrise_widget' title='Sample CRM FreshPlug'>{{ticket.requester}}</div>",
                       :view_pages => ["helpdesk_tickets_show_page_side_bar", "contacts_show_page_side_bar"]
                      }
                  }
    application.reload
    application.widget.display_in_pages_option.should eql ["helpdesk_tickets_show_page_side_bar", "contacts_show_page_side_bar"]
    response.should redirect_to "/integrations/applications#fresh-plugs"
  end

  it "should disable an application(deletes from installed application)" do
    application = Integrations::Application.find_by_display_name("New Test application")
    put :disable, :id => application.id
    application.reload
    application.installed_applications.should be_blank
    expected_response = {"status" => 200}
    JSON.parse(response.body).should eql expected_response
  end

  it "should enable an application" do
    application = Integrations::Application.find_by_display_name("New Test application")
    put :enable, :id => application.id
    application.reload
    application.installed_applications.should_not be_nil
    expected_response = {"status" => 200}
    JSON.parse(response.body).should eql expected_response
  end

  it "renders custom widget preview partial" do
    post 'custom_widget_preview'
    response.should render_template("integrations/widgets/_custom_widget_preview")
  end

  it "should delete an aplication" do
    application = Integrations::Application.find_by_display_name("New Test application")
    delete :destroy, :id => application.id
    app = Integrations::Application.find_by_id(application.id)
    app.should be_nil
    app_details = {
                    "name" => application.display_name,
                    "application_id" => application.id,
                    "classic_plug" => true,
                    "status" => 200
                  }
    JSON.parse(response.body).should eql app_details
  end
end