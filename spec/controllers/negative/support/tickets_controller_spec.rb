require 'spec_helper'

describe Support::TicketsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  it "should not allow a user view tickets wwithout logging in" do
    get :index
    response.should redirect_to '/login'
  end

  it "should not allow a user to access tickets from a different company" do
    company = FactoryGirl.build(:customer, :name => Faker::Name.name)
    company.save
    test_user1 = FactoryGirl.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3, :customer_id => company.id)
    test_user1.save
    now = (Time.now.to_f*1000).to_i
    test_ticket = create_ticket({ :status => 2, :requester_id => test_user1.id, :subject => "#{now}" }, 
                                  create_group(@account, {:name => "Tickets"}))
    test_user2 = FactoryGirl.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3, :customer_id => company.id)
    test_user2.save
    log_in(test_user2)
    get :index
    response.body.should_not =~ /#{now}/
    response.should render_template 'support/tickets/index'
    get :show, :id => test_ticket.display_id
    response.should redirect_to '/support/login'
  end

  it "should not allow a user to update inaccessible attributes" do
    user1 = FactoryGirl.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
    user1.save
    user2 = FactoryGirl.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
    user2.save
    now = (Time.now.to_f*1000).to_i
    ticket = create_ticket({ :status => 2, :requester_id => user1.id, :subject => "#{now}" })
    put :update, :id => ticket.display_id, 
                 :helpdesk_ticket => { :status => "2", 
                                       :priority => "1",
                                       :requester_id => user2,
                                       :source => "6",
                                       :spam => true,
                                       :deleted => true
                                      }
    ticket = @acc.tickets.find_by_subject(now)
    ticket.requester_id.should be_eql(user1.id)
    ticket.source.should_not be_eql(6)
    ticket.spam.should be_falsey
    ticket.deleted.should be_falsey
  end
end 