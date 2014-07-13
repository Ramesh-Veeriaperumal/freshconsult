require 'spec_helper'
include Redis::TicketsRedis
include Redis::RedisKeys

describe Helpdesk::TicketsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
    @group = @account.groups.first
  end

  before(:each) do
    log_in(@agent)
  end

  it "should go to the index page" do
    get 'index'
    response.should render_template "helpdesk/tickets/index.html.erb"
    response.body.should =~ /Filter Tickets/
  end

  it "should create a new ticket" do
    now = (Time.now.to_f*1000).to_i
    post :create, :helpdesk_ticket => {:email => Faker::Internet.email,
                                       :requester_id => "",
                                       :subject => "New Ticket #{now}",
                                       :ticket_type => "Question",
                                       :source => "3",
                                       :status => "2",
                                       :priority => "1",
                                       :group_id => "",
                                       :responder_id => "",
                                       :ticket_body_attributes => {"description_html"=>"<p>Testing</p>"}
                                      }
    @account.tickets.find_by_subject("New Ticket #{now}").should be_an_instance_of(Helpdesk::Ticket)
  end

  # Ticket Updates

    it "should edit a ticket" do
      now = (Time.now.to_f*1000).to_i
      get :edit, :id => @test_ticket.display_id
      response.body.should =~ /Edit ticket/
      put :update, :id => @test_ticket.display_id,
                   :helpdesk_ticket => { :email => Faker::Internet.email,
                                         :requester_id => "",
                                         :subject => "Edit Ticket #{now}",
                                         :ticket_type => "Question",
                                         :source => "2",
                                         :status => "2",
                                         :priority => "3",
                                         :group_id => "",
                                         :responder_id => "",
                                         :ticket_body_attributes => {"description_html"=>"<p>Editing...</p>"}
                                        }
      @account.tickets.find_by_subject("Edit Ticket #{now}").should be_an_instance_of(Helpdesk::Ticket)
    end

    it "should update a ticket's properties" do
      put :update_ticket_properties, { :helpdesk_ticket => { :priority => "4",
                                                             :status => "3",
                                                             :source => "9",
                                                             :ticket_type => "Lead",
                                                             :group_id => "",
                                                             :responder_id => ""
                                                            },
                                       :helpdesk => { :tags => ""},
                                       :id => @test_ticket.display_id
                                      }
      updated_ticket = @account.tickets.find(@test_ticket.id)
      updated_ticket.ticket_type.should be_eql("Lead")
      updated_ticket.source.should be_eql(9)
    end

    it "should update the due date of a ticket" do
      due_date = (Time.now+10.days).to_date.strftime("%a %b %d %Y %H:%M:%S")
      put :change_due_by, { :due_date_options => "specific",
                            :due_by_hour => "3",
                            :due_by_minute => "00",
                            :due_by_am_pm => "PM",
                            :due_by_date_time => due_date,
                            :id => @test_ticket.display_id
                          }
      @account.tickets.find(@test_ticket.id).due_by.to_date.should be_eql(due_date.to_date)
    end

    it "should save draft for a ticket" do
      draft_key = HELPDESK_REPLY_DRAFTS % { :account_id => @account.id, :user_id => @agent.id,
        :ticket_id => @test_ticket.id}
      post :save_draft, { :draft_data => "<p>Testing save_draft</p>", :id => @test_ticket.display_id }
      get_tickets_redis_key(draft_key).should be_eql("<p>Testing save_draft</p>")
    end

    it "should execute a scenario" do
      @request.env['HTTP_REFERER'] = 'sessions/new'
      scenario_ticket = create_ticket({ :status => 2 }, @group)
      scenario = @account.scn_automations.find_by_name("Mark as Feature Request")
      put :execute_scenario, :scenario_id => scenario.id, :id => scenario_ticket.display_id
      @account.tickets.find(scenario_ticket.id).ticket_type.should be_eql("Feature Request")
    end

    it "should close a ticket without notifying the customer on shift_close_ticket+Close" do
      shift_close_ticket = create_ticket({ :status => 2 }, @group)
      put :update_ticket_properties, { :helpdesk_ticket => { :priority => "1",
                                                             :status => "5",
                                                             :source => "3",
                                                             :ticket_type => "Question",
                                                             :group_id => "",
                                                             :responder_id => ""
                                                            },
                                       :helpdesk => {"tags"=>""},
                                       :disable_notification => "true",
                                       :redirect => "true",
                                       :id => shift_close_ticket.display_id
                                      }
      @account.tickets.find(shift_close_ticket.id).status.should be_eql(5)
      Delayed::Job.last.handler.should include("biz_rules_check")
      Delayed::Job.last.handler.should include("update_status")
    end


  # Ticket Quick Assign Triplet

    it "should quick-assign an agent to a ticket" do
      put :quick_assign, { :assign => "agent", :value => @agent.id, :id => @test_ticket.display_id,
                           :disable_notification => false, :_method => "put" }
      response.body.should be_eql({:success => true}.to_json)
      @account.tickets.find(@test_ticket.id).responder_id.should be_eql(@agent.id)
    end

    it "should quick-assign status of a ticket" do
      put :quick_assign, { :assign => "status", :value => 3, :id => @test_ticket.display_id }
      response.body.should be_eql({:success => true}.to_json)
      @account.tickets.find(@test_ticket.id).status.should be_eql(3)
    end

    it "should quick-assign priority of a ticket" do
      put :quick_assign, { :assign => "priority", :value => 3, :id => @test_ticket.display_id }
      response.body.should be_eql({:success => true}.to_json)
      @account.tickets.find(@test_ticket.id).priority.should be_eql(3)
    end


  # Ticket Top Nav Bar

    it "should assign multiple tickets to the current user" do
      pick_ticket1 = create_ticket({ :status => 2 }, @group)
      pick_ticket2 = create_ticket({ :status => 2 }, @group)
      @request.env['HTTP_REFERER'] = 'sessions/new'
      put :pick_tickets, { :id => "multiple",
                           :ids => ["#{pick_ticket1.display_id}", "#{pick_ticket2.display_id}"]}
      picked_tickets = @account.tickets.find_all_by_responder_id(@agent.id).map(&:id)
      picked_tickets.include?(pick_ticket1.id).should be_true
      picked_tickets.include?(pick_ticket2.id).should be_true
    end

    it "should assign multiple tickets to a specific agent" do
      new_agent = add_agent(@account, {  :name => Faker::Name.name,
                                        :email => Faker::Internet.email,
                                        :active => 1,
                                        :role => 1,
                                        :agent => 1,
                                        :ticket_permission => 1,
                                        :role_ids => ["#{@account.roles.first.id}"] })

      assign_ticket1 = create_ticket({ :status => 2 }, @group)
      assign_ticket2 = create_ticket({ :status => 2 }, @group)
      @request.env['HTTP_REFERER'] = 'sessions/new'
      put :assign, { :id => "multiple", :responder_id => new_agent.id,
                    :ids => ["#{assign_ticket1.display_id}", "#{assign_ticket2.display_id}"]}
      assigned_tickets = @account.tickets.find_all_by_responder_id(new_agent.id).map(&:id)
      assigned_tickets.include?(assign_ticket1.id).should be_true
      assigned_tickets.include?(assign_ticket2.id).should be_true
    end

    it "should close multiple tickets" do
      close_ticket1 = create_ticket({ :status => 2 }, @group)
      close_ticket2 = create_ticket({ :status => 2 }, @group)
      @request.env['HTTP_REFERER'] = 'sessions/new'
      put :close_multiple, { :id => "multiple",
                             :ids => ["#{close_ticket1.display_id}", "#{close_ticket2.display_id}"]}
      closed_tickets = @account.tickets.find_all_by_status(5).map(&:id)
      closed_tickets.include?(close_ticket1.id).should be_true
      closed_tickets.include?(close_ticket2.id).should be_true
    end

    it "should mark multiple tickets as spam" do
      spam_ticket1 = create_ticket({ :status => 2 }, @group)
      spam_ticket2 = create_ticket({ :status => 2 }, @group)
      @request.env['HTTP_REFERER'] = 'sessions/new'
      put :spam, { :id => "multiple",
                   :ids => ["#{spam_ticket1.display_id}", "#{spam_ticket2.display_id}"]}
      spammed_tickets = @account.tickets.find_all_by_spam(1).map(&:id)
      spammed_tickets.include?(spam_ticket1.id).should be_true
      spammed_tickets.include?(spam_ticket2.id).should be_true
    end

    it "should delete multiple tickets" do
      del_ticket1 = create_ticket({ :status => 2 }, @group)
      del_ticket2 = create_ticket({ :status => 2 }, @group)
      delete :destroy, { :id => "multiple",
                         :ids => ["#{del_ticket1.display_id}", "#{del_ticket2.display_id}"]}
      deleted_tickets = @account.tickets.find_all_by_deleted(1).map(&:id)
      deleted_tickets.include?(del_ticket1.id).should be_true
      deleted_tickets.include?(del_ticket2.id).should be_true
    end


  # Spam and Delete

    it "should mark a ticket as spam" do
      put :spam, :id => @test_ticket.display_id
      @account.tickets.find(@test_ticket.id).spam.should be_true
    end

    it "should delete a ticket" do
      delete :destroy, :id => @test_ticket.display_id
      @account.tickets.find(@test_ticket.id).deleted.should be_true
    end

    it "should unspam a ticket from spam view" do
      tkt1 = create_ticket({ :status => 2 }, @group)
      tkt2 = create_ticket({ :status => 2 }, @group)
      spam_tkt_arr = []
      spam_tkt_arr.push(tkt1.display_id.to_s, tkt2.display_id.to_s)
      put :spam, :id => "multiple", :ids => spam_tkt_arr
      tkt1.reload
      tkt2.reload
      get :filter_options, :filter_name => "spam"
      put :unspam, :id => "multiple", :ids => spam_tkt_arr
      tkt1.reload
      tkt2.reload
      @account.tickets.find(tkt1.id).spam.should be_false
      @account.tickets.find(tkt2.id).spam.should be_false
    end

  # Tickets filter
    it "should return ticket for tickets created today in created at filter" do
      created_at_timestamp = "#{Time.zone.now.to_f} - #{Time.zone.now.beginning_of_day.to_i}"
      ticket_created = create_ticket({ :status => 2, :subject => created_at_timestamp, :created_at => Time.zone.now.beginning_of_day+1.hour}, create_group(@account, {:name => "Tickets_list"}))
      get "custom_search" , {
        "data_hash" => ActiveSupport::JSON.encode([{condition: "created_at", operator: "is_greater_than", ff_name: "default", value: "today"}]),
        "filter_name" => "all_tickets",
        "wf_order" => "updated_at",
        "wf_order_type" => "desc",
        "page" => 1,
        "total_entries" => 0,
        "unsaved_view" => true
      }
      (assigns(:items).include? ticket_created).should be_true
      (response.body.include? created_at_timestamp).should be_true
    end

    it "should return tickets created yesterday" do
      created_at_timestamp = "#{Time.zone.now.to_f} - #{Time.zone.now.yesterday.beginning_of_day.to_i}"
      ticket_created = create_ticket({ :status => 2, :subject => created_at_timestamp, :created_at => Time.zone.now.yesterday.beginning_of_day+1.hour}, create_group(@account, {:name => "Tickets_list"}))
      get "custom_search" , {
        "data_hash" => ActiveSupport::JSON.encode([{condition: "created_at", operator: "is_greater_than", ff_name: "default", value: "yesterday"}]),
        "filter_name" => "all_tickets",
        "wf_order" => "updated_at",
        "wf_order_type" => "desc",
        "page" => 1,
        "total_entries" => 0,
        "unsaved_view" => true
      }
      (assigns(:items).include? ticket_created).should be_true
      (response.body.include? created_at_timestamp).should be_true
    end

    it "should return tickets created within this week" do
      created_at_timestamp = "#{Time.zone.now.to_f} - #{Time.zone.now.beginning_of_week.to_i}"
      ticket_created = create_ticket({ :status => 2, :subject => created_at_timestamp, :created_at => Time.zone.now.beginning_of_week+1.hour}, create_group(@account, {:name => "Tickets_list"}))
      get "custom_search" , {
        "data_hash" => ActiveSupport::JSON.encode([{condition: "created_at", operator: "is_greater_than", ff_name: "default", value: "week"}]),
        "filter_name" => "all_tickets",
        "wf_order" => "updated_at",
        "wf_order_type" => "desc",
        "page" => 1,
        "total_entries" => 0,
        "unsaved_view" => true
      }
      (assigns(:items).include? ticket_created).should be_true
      (response.body.include? created_at_timestamp).should be_true
    end

    it "should return tickets created within this month" do
      created_at_timestamp = "#{Time.zone.now.to_f} - #{Time.zone.now.beginning_of_month.to_i}"
      ticket_created = create_ticket({ :status => 2, :subject => created_at_timestamp, :created_at => Time.zone.now.beginning_of_month+1.hour}, create_group(@account, {:name => "Tickets_list"}))
      get "custom_search" , {
        "data_hash" => ActiveSupport::JSON.encode([{condition: "created_at", operator: "is_greater_than", ff_name: "default", value: "month"}]),
        "filter_name" => "all_tickets",
        "wf_order" => "updated_at",
        "wf_order_type" => "desc",
        "page" => 1,
        "total_entries" => 0,
        "unsaved_view" => true
      }
      (assigns(:items).include? ticket_created).should be_true
      (response.body.include? created_at_timestamp).should be_true
    end

    it "should return tickets created within 2 months" do
      created_at_timestamp = "#{Time.zone.now.to_f} - #{Time.zone.now.beginning_of_day.ago(2.months).to_i}"
      ticket_created = create_ticket({ :status => 2, :subject => created_at_timestamp, :created_at => Time.zone.now.beginning_of_day.ago(2.months)+1.hour}, create_group(@account, {:name => "Tickets_list"}))
      get "custom_search" , {
        "data_hash" => ActiveSupport::JSON.encode([{condition: "created_at", operator: "is_greater_than", ff_name: "default", value: "two_months"}]),
        "filter_name" => "all_tickets",
        "wf_order" => "updated_at",
        "wf_order_type" => "desc",
        "page" => 1,
        "total_entries" => 0,
        "unsaved_view" => true
      }
      (assigns(:items).include? ticket_created).should be_true
      (response.body.include? created_at_timestamp).should be_true
    end

    it "should return tickets created within 6 months" do
      created_at_timestamp = "#{Time.now.to_f} - #{Time.zone.now.beginning_of_day.ago(6.months).to_i}"
      ticket_created = create_ticket({ :status => 2, :subject => created_at_timestamp, :created_at => Time.zone.now.beginning_of_day.ago(6.months)+1.hour}, create_group(@account, {:name => "Tickets_list"}))
      get "custom_search" , {
        "data_hash" => ActiveSupport::JSON.encode([{condition: "created_at", operator: "is_greater_than", ff_name: "default", value: "six_months"}]),
        "filter_name" => "all_tickets",
        "wf_order" => "updated_at",
        "wf_order_type" => "desc",
        "page" => 1,
        "total_entries" => 0,
        "unsaved_view" => true
      }
      (assigns(:items).include? ticket_created).should be_true
      (response.body.include? created_at_timestamp).should be_true
    end

    it "should return tickets created within mins of integer values" do
      created_at_timestamp = "#{Time.zone.now.to_f} - #{Time.zone.now.to_i}"
      ticket_created = create_ticket({ :status => 2, :subject => created_at_timestamp, :created_at => Time.zone.now}, create_group(@account, {:name => "Tickets_list"}))
      get "custom_search" , {
        "data_hash" => ActiveSupport::JSON.encode([{condition: "created_at", operator: "is_greater_than", ff_name: "default", value: "20"}]),
        "filter_name" => "all_tickets",
        "wf_order" => "updated_at",
        "wf_order_type" => "desc",
        "page" => 1,
        "total_entries" => 0,
        "unsaved_view" => true
      }
      (assigns(:items).include? ticket_created).should be_true
      (response.body.include? created_at_timestamp).should be_true
    end

    it "should show the custom view save popup" do
      created_at_timestamp = "#{Time.zone.now.to_f} - #{Time.zone.now.beginning_of_week.to_i}"
      ticket_created = create_ticket({ :status => 2, :subject => created_at_timestamp, :created_at => Time.zone.now.beginning_of_week+1.hour}, create_group(@account, {:name => "Tickets_list"}))
      get "custom_search" , {
        "data_hash" => ActiveSupport::JSON.encode([{condition: "created_at", operator: "is_greater_than", ff_name: "default", value: "week"}]),
        "filter_name" => "all_tickets",
        "wf_order" => "updated_at",
        "wf_order_type" => "desc",
        "page" => 1,
        "total_entries" => 0,
        "unsaved_view" => true
      }
      get :custom_view_save, :operation => "save_as"
      response.should render_template "helpdesk/tickets/customview/_new.html.erb"
    end

    it "should return new tickets page through topic" do
      forum_category = create_test_category
      forum = create_test_forum(forum_category)
      topic = create_test_topic(forum)
      publish_topic(topic)
      get :new , {"topic_id" => topic.id }
      response.should render_template "helpdesk/tickets/new.html.erb"
      response.body.should =~ /"#{topic.title}"/
    end

    it "should display latest note for ticket" do
      tkt1 = create_ticket({ :status => 2 }, @group)
      body = "Latest note for the ticket is being displayed"
      tkt1_note = create_note({:source => tkt1.source,
                               :ticket_id => tkt1.id,
                               :body => body,
                               :user_id => @agent.id})
      tkt1.reload
      tkt1_note.reload
      get :latest_note , :id => tkt1.display_id
      response.should render_template "helpdesk/shared/_ticket_overlay.html.erb"
      response.body.should =~ /#{body}/
      tkt2 = create_ticket({ :status => 2 }, @group)
      tkt2.reload
      get :latest_note , :id => tkt2.display_id
      response.should render_template "helpdesk/shared/_ticket_overlay.html.erb"
      response.body.should =~ /#{tkt2.description}/
    end

end
