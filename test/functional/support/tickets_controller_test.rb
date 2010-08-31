require 'test_helper'

class Support::TicketsControllerTest < ActionController::TestCase
  context "on get to index by logged-in user" do
    setup do
      stub_user
      get :index
    end

    should_render_with_layout 'default'
    should_assign_to :tickets
    should_respond_with :success
    should_render_template :index
    should_not_set_the_flash

    should "load correct records" do
      assert_equal Helpdesk::Ticket.find_all_by_requester_id(@user.id), assigns(:tickets)
    end
  end

  context "on get to index by anon user" do
    setup do
      get :index
    end
    should_not_assign_to :tickets
    should_respond_with :redirect
  end

  context "with @ticket loaded" do
    setup do
      @ticket = Helpdesk::Ticket.first
    end

    context "on get to show by anon user without access token" do
      setup do
        get :show, :id =>  @ticket.to_param
      end
      should_respond_with :redirect
    end
    
    context "on get to show by staff member with appropriate priveleges" do
      setup do
        allow_all
        stub_user
        get :show, :id =>  @ticket.to_param
      end
      should_assign_to :ticket
      should_respond_with :success
      should_render_with_layout 'default'
      should_render_template :show
      should_not_set_the_flash
    end

    context "on get to show by logged in user who is ticket requester" do
      setup do
        stub_user
        @ticket.requester = @user
        @ticket.save!
        get :show, :id =>  @ticket.to_param
      end
      should_assign_to :ticket
      should_respond_with :success
      should_render_with_layout 'default'
      should_render_template :show
      should_not_set_the_flash
    end

    context "on get to show by anonymous user with correct access token" do
      setup do
        get :show, :id =>  @ticket.to_param, :access_token => @ticket.access_token
      end
      should_assign_to :ticket
      should_respond_with :success
      should_render_with_layout 'default'
      should_render_template :show
      should_not_set_the_flash
    end

  end

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
    should_redirect_to "support_ticket_url(@ticket, :access_token => @ticket.access_token)"
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
