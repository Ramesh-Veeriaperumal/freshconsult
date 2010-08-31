require 'test_helper'

class Support::MinimalTicketsControllerTest < ActionController::TestCase

  context "on get to new by anonymous" do
    setup do
      allow_all
      get :new
    end
    should_assign_to :ticket
    should_render_a_form
    should_render_template :new
    should_not_show_form_errors
  end

  context "on get to new by logged in user" do
    setup do
      allow_all
      stub_user
      get :new
    end
    should_assign_to :ticket
    should_render_a_form
    should_render_template :new
    should_not_show_form_errors

    should "use user name and email as defaults" do
      assert_equal @user.name, assigns(:ticket).name
      assert_equal @user.email, assigns(:ticket).email
    end
  end

  context "on valid post to create" do
    setup do
      allow_all
      @params = {:name => 'Billy Jean', :email => "billy@email.com", :description => "She's just a girl who thinks I am the one"}
      post :create, :helpdesk_ticket => @params
    end
    should_assign_to :ticket
    should_redirect_to "support_minimal_ticket_url(@ticket)"
    should_set_the_flash_to "Your request has been created and a copy has been sent to you via email."
    should_change "Helpdesk::Ticket.count", :by => 1
    should "create ticket with @params" do
      ticket = Helpdesk::Ticket.last
      @params.each { |k, v| assert_equal v, ticket.send(k) }
    end

    should "send email" do
      assert_sent_email do |email|
        (email.body.include? "She's just a girl who thinks I am the one") &&
        (email.subject == Helpdesk::EMAIL[:reply_subject] + " " + Helpdesk::Ticket.last.encode_id_token) &&
        (email.to.include? "billy@email.com")
      end
    end
  end

  context "on invalid post to create" do
    setup do
      allow_all
      @params = {:name => ''}
      post :create, :helpdesk_ticket => @params
    end
    should_assign_to :ticket
    should_not_change "Helpdesk::Ticket.count"
    should_render_a_form
    should_render_template :new
    should_show_form_errors
  end

end
