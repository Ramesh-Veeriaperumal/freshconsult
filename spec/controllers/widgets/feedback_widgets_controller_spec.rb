require 'spec_helper'

describe Widgets::FeedbackWidgetsController do
	# integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user = add_test_agent(@account)
  end

  before(:each) do
    login_admin
  end

  it "renders the widgets new html template" do
    get 'new', { :format => 'html' }
    response.should be_success
    response.should render_template "widgets/feedback_widgets/new.html.erb"
  end

  it "renders the thanks template" do
    get 'thanks'
    response.should be_success
    response.should render_template "widgets/feedback_widgets/thanks.html.erb"
  end

  it "should create a new ticket" do
    now = (Time.now.to_f*1000).to_i
    post :create, :helpdesk_ticket => {:email => Faker::Internet.email,
                                       :requester_id => "",
                                       :subject => "New Ticket #{now}",
                                       :ticket_type => "Question",
                                       :source => "3",
                                       :status => "2",
                                       :priority => "1"}
    RSpec.configuration.account.tickets.find_by_subject("New Ticket #{now}").should be_an_instance_of(Helpdesk::Ticket)
    response.should render_template "widgets/feedback_widgets/thanks.html.erb"
  end

  it "should redirect to feedback_widgets/new if ticket creation fails" do
    get 'new'
    now = (Time.now.to_f*1000).to_i
    Widgets::FeedbackWidgetsController.any_instance.stubs(:create_the_ticket => false)
    post :create, :helpdesk_ticket => {:email => Faker::Internet.email,
                                       :requester_id => "",
                                       :subject => "New Ticket #{now}",
                                       :ticket_type => "Question",
                                       :source => "3",
                                       :status => "2",
                                       :priority => "1"}
    response.should render_template "widgets/feedback_widgets/new.html.erb"
  end

end