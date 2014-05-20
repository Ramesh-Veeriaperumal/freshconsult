require 'spec_helper'

describe Support::TicketsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  it "should not allow a user view tickets wwithout logging in" do
    get :index
    response.should redirect_to 'login'
  end

  it "should not allow a user to access tickets from a different company" do
    company = Factory.build(:customer, :name => Faker::Name.name)
    company.save
    test_user1 = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3, :customer_id => company.id)
    test_user1.save
    now = (Time.now.to_f*1000).to_i
    test_ticket = create_ticket({ :status => 2, :requester => test_user1, :subject => "#{now}" }, 
                                  create_group(@account, {:name => "Tickets"}))
    test_user2 = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3, :customer_id => company.id)
    test_user2.save
    log_in(test_user2)
    get :index
    response.body.should_not =~ /#{now}/
    response.should render_template 'support/tickets/index.portal'
    get :show, :id => test_ticket.display_id
    response.should redirect_to 'support/login'
  end
end
