require 'spec_helper'

describe Widgets::FeedbackWidgetsController do
  setup :activate_authlogic
  include AccountHelper
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
    response.should render_template "widgets/feedback_widgets/new"
  end

  it "renders the thanks template" do
    now = (Time.now.to_f*1000).to_i
    get 'thanks' , widget_params(now)
    response.should be_success
    response.should render_template "widgets/feedback_widgets/thanks"
  end

  it "should create a new ticket" do
    now = (Time.now.to_f*1000).to_i
    post :create, widget_params(now)
    @account.tickets.find_by_subject("New Ticket #{now}").should be_an_instance_of(Helpdesk::Ticket)
    expect(response.status).to eql(200)
    result = parse_json(response)
    expect(result["success"]).to eql(true)
  end

  it "should redirect to feedback_widgets/new if ticket creation fails" do
    get 'new'
    now = (Time.now.to_f*1000).to_i
    Widgets::FeedbackWidgetsController.any_instance.stubs(:create_the_ticket => false)
    post :create, widget_params(now)    
    result = parse_json(response)
    expect(result["success"]).to eql(false)
  end

  describe "Multilingual Feature" do

    it "should render new html template without redirect when Multilingual is enabled for the account" do
      destroy_enable_multilingual_feature if @account.multilingual?
      get 'new', { :format => 'html' }
      expect(response.status).to eql(200)
      expect(response).to render_template("widgets/feedback_widgets/new")
      expect(response.status).not_to eql(302) #making sure it's not a redirect
    end

    it "should render new html template without redirect when Multilingual is enabled for the account" do
      enable_multilingual unless @account.multilingual?
      get 'new', { :format => 'html' }
      expect(response.status).to eql(200)
      expect(response).to render_template("widgets/feedback_widgets/new")
      expect(response.status).not_to eql(302) #making sure it's not a redirect
    end
  end

end