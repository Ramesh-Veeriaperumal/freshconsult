require 'test_helper'

class Helpdesk::TicketsControllerTest < ActionController::TestCase

  context "all permissions granted" do
    setup do
      stub_user
      allow_all
      set_referrer
    end

    context "on get to :index with no filters or search terms specified" do
      setup do
        get :index
      end
      should_assign_to :items
      should_respond_with :success
      should_render_template :index
      should_not_set_the_flash
    end

    context "on get to :show with invalid ticket id" do
      setup do
        Helpdesk::Ticket.expects(:find_by_param).with("invalid_id").returns(nil)
        assert_raise ActiveRecord::RecordNotFound do
          get :show, :id => "invalid_id"
        end
      end
      should_not_assign_to :item, :ticket
      should_not_set_the_flash
    end

    context "on get to :show with valid ticket id" do
      setup do
        @ticket = new_ticket
        @subscription = Helpdesk::Subscription.new(
          :ticket_id => @ticket.id,
          :user_id => @user.id
        )
        @subscription.stubs(:id).returns(42)
        Helpdesk::Ticket.expects(:find_by_param).with("valid_id").returns(@ticket)
        Helpdesk::Subscription.expects(:find).returns(@subscription)
        get :show, :id => "valid_id"
      end

      should_respond_with :success
      should_not_set_the_flash
      should_render_template :show

      should "assign ticket and subscription to instance vars" do
        assert_same @ticket, assigns(:item)
        assert_same @ticket, assigns(:ticket)
        assert_same @subscription, assigns(:subscription)
      end
    end

    context "without rendering" do 
      setup do
        @controller.stubs(:render)
        @items = mock
      end

      should "Get :index once with each filter" do
        [
          [:open, :unassigned],
          [:open, :responded_by],
          [:open, :monitored_by],
          [:open, :visible],
          [:all, :unassigned],
          [:all, :responded_by],
          [:all, :monitored_by],
          [:all, :visible],
          [:all, :spam],
          [:all, :deleted]
        ].each do |f|
          Helpdesk::Ticket.expects(:filter).with(f, @user).returns(@items)
          Helpdesk::Ticket.expects(:search).with(@items, nil, nil).returns(@items)
          @items.expects(:paginate).returns(@items)
          get :index, :filters => f
          assert_same @items, assigns(:items)
        end
      end

      should "Get :index once with each search field" do
        [:name, :phone, :email, :description, :source].each do |f|
          Helpdesk::Ticket.expects(:filter).with([:open, :unassigned], @user).returns(@items)
          Helpdesk::Ticket.expects(:search).with(@items, f, "abc").returns(@items)
          @items.expects(:paginate).returns(@items)
          get :index, :f => f, :v => "abc"
          assert_same @items, assigns(:items)
        end
      end


      should "Get :index once with each sort field" do
        Helpdesk::Ticket::SORT_SQL_BY_KEY.each do |k, s|
          Helpdesk::Ticket.expects(:filter).with([:open, :unassigned], @user).returns(@items)
          Helpdesk::Ticket.expects(:search).with(@items, nil, nil).returns(@items)
          @items.expects(:paginate).with(:page => '1', :order => s, :per_page => 10).returns(@items)
          get :index, :page => 1, :sort => k
          assert_same @items, assigns(:items)
        end
      end
    end


    context "on :put to :assign with single valid id and no responder_id specified" do
      setup do
        @ticket = new_ticket_for_assign
        Helpdesk::Ticket.expects(:find_by_param).times(2).with("valid_id").returns(@ticket)
        put :assign, :id => 'valid_id'
      end
      should_assign_to :items, :tickets
      should_set_the_flash_to "1 ticket was assigned to Joe Bob."

      should "assign loaded ticket to @items and @tickets" do
        assert_equal [@ticket], assigns(:tickets)
        assert_equal [@ticket], assigns(:items)
      end
    end

    context "on :put to :assign with multiple valid ids and no responder_id specified" do
      setup do
        @tickets = (1..10).map do |i|
          t = new_ticket_for_assign
          Helpdesk::Ticket.expects(:find_by_param).times(2).with("#{i}").returns(t)
          t
        end
        put :assign, :ids => %w{1 2 3 4 5 6 7 8 9 10}
      end

      should_assign_to :items, :tickets
      should_redirect_to back
      should_set_the_flash_to "10 tickets were assigned to Joe Bob."

      should "assign loaded tickets to @items and @tickets" do
        assert_equal @tickets, assigns(:tickets)
        assert_equal @tickets, assigns(:items)
      end
    end

    context "on :put to :assign with multiple valid ids and a valid responder_id specified" do
      setup do
        user = User.new(:id => 777, :name => "Jim Bob")
        User.expects(:find).with('777').returns(user)
        @tickets = (1..10).map do |i|
          t = new_ticket_for_assign(user)
          Helpdesk::Ticket.expects(:find_by_param).times(2).with("#{i}").returns(t)
          t
        end
        put :assign, :ids => %w{1 2 3 4 5 6 7 8 9 10}, :responder_id => 777
      end

      should_assign_to :items, :tickets
      should_redirect_to back
      should_set_the_flash_to "10 tickets were assigned to Jim Bob."

      should "assign loaded tickets to @items and @tickets" do
        assert_equal @tickets, assigns(:tickets)
        assert_equal @tickets, assigns(:items)
      end
    end

    context "on :put to :assign with single invalid id" do
      setup do
        Helpdesk::Ticket.expects(:find_by_param).times(2).with("invalid_id").returns(nil)
        put :assign, :id => 'invalid_id'
      end
      should_assign_to :items, :tickets
      should_redirect_to back
      should_set_the_flash_to "0 tickets were assigned to Joe Bob."
      should "assign loaded ticket to @items and @tickets" do
        assert_equal [], assigns(:tickets)
        assert_equal [], assigns(:items)
      end
    end

    context "on :put to :assign with multiple invalid ids" do
      setup do
        10.times do |i|
          Helpdesk::Ticket.expects(:find_by_param).times(2).with("#{i}").returns(nil)
        end
        put :assign, :ids => %w{0 1 2 3 4 5 6 7 8 9}
      end

      should_assign_to :items, :tickets
      should_redirect_to back
      should_set_the_flash_to "0 tickets were assigned to Joe Bob."

      should "assign loaded ticket to @items and @tickets" do
        assert_equal [], assigns(:tickets)
        assert_equal [], assigns(:items)
      end
    end

    context "on :put to :assign with some valid and some invalid ids" do
      setup do
        (1..10).each do |i|
          Helpdesk::Ticket.expects(:find_by_param).times(2).with("#{i}").returns(
            i%2==1 ? new_ticket_for_assign : nil
          )
        end
        put :assign, :ids => %w{1 2 3 4 5 6 7 8 9 10}
      end

      should_assign_to :items, :tickets
      should_redirect_to back
      should_set_the_flash_to "5 tickets were assigned to Joe Bob."
    end

    context "on :put to :spam with multiple valid ids" do
      setup do
        @tickets = (1..10).map do |i|
          ticket = new_ticket
          ticket.expects(:train).with(:spam)
          ticket.expects(:save).returns(true)
          Helpdesk::Ticket.expects(:find_by_param).times(2).with("#{i}").returns(ticket)
          ticket
        end
        put :spam, :ids => %w{1 2 3 4 5 6 7 8 9 10}
      end

      should_assign_to :items, :tickets
      should_redirect_to back
      should "set flash" do
        assert_match(/^10 tickets were flagged as spam/, flash[:notice])
      end

      should "assign loaded tickets to @items and @tickets" do
        assert_equal @tickets, assigns(:tickets)
        assert_equal @tickets, assigns(:items)
      end
    end

    context "on :put to :unspam with multiple valid ids" do
      setup do
        @tickets = (1..10).map do |i|
          ticket = new_ticket
          ticket.expects(:train).with(:ham)
          ticket.expects(:save).returns(true)
          Helpdesk::Ticket.expects(:find_by_param).times(2).with("#{i}").returns(ticket)
          ticket
        end
        put :unspam, :ids => %w{1 2 3 4 5 6 7 8 9 10}
      end

      should_assign_to :items, :tickets
      should_redirect_to back
      should "set flash" do
        assert_match(/^10 tickets were removed from the spam folder/, flash[:notice])
      end

      should "assign loaded tickets to @items and @tickets" do
        assert_equal @tickets, assigns(:tickets)
        assert_equal @tickets, assigns(:items)
      end
    end

    context "on :delete to :empty_trash" do
      setup do
        Helpdesk::Ticket.expects(:destroy_all).with(:deleted=>true)
        delete :empty_trash
      end
      should_redirect_to back
      should_set_the_flash_to "All tickets in the trash folder were deleted."
    end

    context "on :delete to :empty_spam" do
      setup do
        Helpdesk::Ticket.expects(:destroy_all).with(:spam=>true)
        delete :empty_spam
      end
      should_redirect_to back
      should_set_the_flash_to "All tickets in the spam folder were deleted."
    end

    context "on valid post to create" do
      setup do
        @params = {:name => 'Josie Sue', :email => 'josie@email.com', :status => 1, :source => 0}
        post :create, :helpdesk_ticket => @params
      end
      should_assign_to :item, :ticket
      should_redirect_to "helpdesk_ticket_url(@item)"
      should_set_the_flash_to "The ticket has been created"
      should_change "Helpdesk::Ticket.count", :by => 1
      should "Create ticket with @params" do
        ticket = Helpdesk::Ticket.last
        @params.each { |k, v| assert_equal v, ticket.send(k) }
      end
    end

    context "on valid post to create with save_and_create specified" do
      setup do
        @params = {:name => 'Josie Sue', :email => 'josie@email.com', :status => 1, :source => 0}
        post :create, :helpdesk_ticket => @params, :save_and_create => true
      end
      should_assign_to :item, :ticket
      should_redirect_to "new_helpdesk_ticket_url"
      should_set_the_flash_to "The ticket has been created"
      should_change "Helpdesk::Ticket.count", :by => 1
      should "Create ticket with @params" do
        ticket = Helpdesk::Ticket.last
        @params.each { |k, v| assert_equal v, ticket.send(k) }
      end
    end

    context "on invalid post to create" do
      setup do
        @params = {:name => '', :email => 'josie@email.com', :status => 1, :source => 0}
        post :create, :helpdesk_ticket => @params
      end
      should_assign_to :item, :ticket
      should_render_a_form
      should_render_template :new
      should_not_change "Helpdesk::Ticket.count"
      should "Build ticket with @params" do
        @params.each { |k, v| assert_equal v, assigns(:ticket).send(k) }
      end
      should "Show form error messages" do
        assert_select "#errorExplanation"
      end
    end

    context "on get to new" do
      setup do
        get :new
      end
      should_assign_to :item, :ticket
      should_render_a_form
      should_render_template :new
      should "not show form error messages" do
        assert_select "#errorExplanation", false
      end
    end

    context "on get to edit with valid id" do
      setup do
        @ticket = Helpdesk::Ticket.last
        get :edit, :id => @ticket.to_param
      end
      should_assign_to :item, :ticket
      should "load correct ticket" do
        assert_equal @ticket.id, assigns(:ticket).id
        assert_equal @ticket.name, assigns(:ticket).name
      end
      should_render_a_form
      should_render_template :edit
      should "not show form error messages" do
        assert_select "#errorExplanation", false
      end
    end

    context "on get to edit with invalid id" do
      setup do
        assert_raise ActiveRecord::RecordNotFound do
          get :edit, :id => "not a valid id"
        end
      end
      should_not_assign_to :item, :ticket
      should_not_set_the_flash
    end

    context "on put to update with invalid id" do
      setup do
        assert_raise ActiveRecord::RecordNotFound do
          put :update, :id => "not a valid id"
        end
      end
      should_not_assign_to :item, :ticket
      should_not_set_the_flash
    end

    context "on valid put to update" do
      setup do
        @ticket = Helpdesk::Ticket.new(:name => "Bobby sue", :email => "test@email.com")
        @ticket.save!
        @params = {:name => 'Billy Jean', :description => "She's just a girl who thinks I am the one"}
        put :update, :id => @ticket.to_param, :helpdesk_ticket => @params
      end
      should_assign_to :item, :ticket
      should_redirect_to "helpdesk_ticket_url(@item)"
      should_set_the_flash_to "The ticket has been updated"
      should_change "Helpdesk::Ticket.count", 1
      should "Create ticket with @params" do
        @ticket.reload
        @params.each { |k, v| assert_equal v, @ticket.send(k) }
      end
    end

    context "on valid put to update with save_and_create specified" do
      setup do
        @ticket = Helpdesk::Ticket.new(:name => "Bobby sue", :email => "test@email.com")
        @ticket.save!
        @params = {:name => 'Billy Jean', :description => "She's just a girl who thinks I am the one"}
        put :update, :id => @ticket.to_param, :helpdesk_ticket => @params, :save_and_create => true
      end
      should_assign_to :item, :ticket
      should_redirect_to "new_helpdesk_ticket_url"
      should_set_the_flash_to "The ticket has been updated"
      should_change "Helpdesk::Ticket.count", 1
      should "Create ticket with @params" do
        @ticket.reload
        @params.each { |k, v| assert_equal v, @ticket.send(k) }
      end
    end

    context "on invalid put to update" do
      setup do
        @ticket = Helpdesk::Ticket.new(:name => "Bobby sue", :email => "test@email.com")
        @ticket.save!
        @params = {:email => "not a valid email address"}
        put :update, :id => @ticket.to_param, :helpdesk_ticket => @params
      end
      should_assign_to :item, :ticket
      should_change "Helpdesk::Ticket.count", 1
      should_render_a_form
      should_render_template :edit
      should "show form error messages" do
        assert_select "#errorExplanation"
      end
    end
    
    context "on delete to destroy with multiple valid ids" do
      setup do
        @tickets = (1..10).map do |i|
          t = new_ticket
          t.expects(:deleted=).with(true)
          t.expects(:save).returns(true)
          Helpdesk::Ticket.expects(:find_by_param).times(2).with("#{i}").returns(t)
          t
        end
        delete :destroy, :ids => %w{1 2 3 4 5 6 7 8 9 10}
      end

      should_assign_to :items, :tickets
      should_redirect_to back

      should "set flash" do
        assert_match(/^10 tickets were deleted/, flash[:notice])
      end

      should "assign loaded tickets to @items and @tickets" do
        assert_equal @tickets, assigns(:tickets)
        assert_equal @tickets, assigns(:items)
      end
    end
    
    context "on put to restore with multiple valid ids" do
      setup do
        @tickets = (1..10).map do |i|
          t = new_ticket
          t.expects(:deleted=).with(false)
          t.expects(:save).returns(true)
          Helpdesk::Ticket.expects(:find_by_param).times(2).with("#{i}").returns(t)
          t
        end
        put :restore, :ids => %w{1 2 3 4 5 6 7 8 9 10}
      end

      should_assign_to :items, :tickets
      should_redirect_to back

      should "set flash" do
        assert_match(/^10 tickets were restored/, flash[:notice])
      end

      should "assign loaded tickets to @items and @tickets" do
        assert_equal @tickets, assigns(:tickets)
        assert_equal @tickets, assigns(:items)
      end
    end


    context "controller's private and protected methods made public" do
      setup { publicize_controller_methods }
      teardown { privatize_controller_methods }

      should "return class_name from Namespace::ClassName" do
        assert_equal "ticket", @controller.cname
      end

      should "return namespace_class_name from Namespace::ClassName" do
        assert_equal "helpdesk_ticket", @controller.nscname
      end

      should "return correct scoper" do
        assert_same Helpdesk::Ticket, @controller.scoper
      end

      should "find_by_id_token when load by param is called" do
        Helpdesk::Ticket.expects(:find_by_id_token).with(999).returns(:some_value)
        assert_equal :some_value, @controller.load_by_param(999)
      end

      should "fetch item when load_item called" do
        Helpdesk::Ticket.expects(:find_by_id_token).with(999).returns(:some_value)
        @controller.expects(:params).returns({:id => 999})
        assert_equal :some_value, @controller.load_item
      end

      should "render not found if load_item called with invalid id" do
        Helpdesk::Ticket.expects(:find_by_id_token).with(999).returns(nil)
        @controller.expects(:params).returns({:id => 999})
        assert_raise ActiveRecord::RecordNotFound do
          @controller.load_item
        end
      end

      should "build a new ticket from params" do
        @controller.expects(:params).returns({'helpdesk_ticket' => {'name' => "bill"}})
        ticket = @controller.build_item
        assert_equal "bill", ticket.name
      end


    end



  end





private

  def new_ticket
    Helpdesk::Ticket.new(
      :id => 666,
      :name => "Carly Customer", 
      :description => "Here's my problem..",
      :email => "test@email.com",
      :id_token => "foo"
    )
  end

  def new_ticket_for_assign(user = false)
    ticket = new_ticket
    ticket.expects(:responder=).with(user || @user)
    ticket.expects(:train).with(:ham)
    ticket.expects(:save).returns(true)
    ticket.expects(:create_status_note)
    return ticket
  end

end
