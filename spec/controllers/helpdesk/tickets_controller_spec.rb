require 'spec_helper'
require 'sidekiq/testing'
include Redis::TicketsRedis
include Redis::RedisKeys
include FacebookHelper

RSpec.describe Helpdesk::TicketsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
    @group = @account.groups.first
    user = add_test_agent(@account)
    @email_config =  @account.email_configs.new(:name => "consoleemailconfig", :to_email => "smething@teting.com", :reply_email => "somehintg@testing.com")
    @email_config.save
    @email_config.reload
    @email_config.update_column(:active, true)
    sla_policy = create_sla_policy(user)
    $redis_tickets.keys("HELPDESK_TICKET_FILTERS*").each {|key| $redis_tickets.del(key)}
    $redis_tickets.keys("HELPDESK_TICKET_ADJACENTS*").each {|key| $redis_tickets.del(key)}
  end

  before(:each) do
    log_in(@agent)
    stub_s3_writes
  end

  it "should go to the index page" do
    get 'index'
    response.should render_template "helpdesk/tickets/index"
    response.body.should =~ /Filter Tickets/
  end
    
  # Added this test case for covering meta_helper_methods.rb
  it "should view a ticket created from portal" do
    ticket = create_ticket({:status => 2},@group)
    meta_data = { :user_agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36\ 
                                              (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36", 
                   :referrer => ""}
    note = ticket.notes.build(
        :note_body_attributes => {:body => meta_data.map { |k, v| "#{k}: #{v}" }.join("\n")},
        :private => true,
        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'],
        :account_id => ticket.account.id,
        :user_id => ticket.requester.id
    )
    note.save_note
    get :show, :id => ticket.display_id
    response.body.should =~ /#{ticket.description_html}/
  end


  it "should create a outbound ticket" do
    @account.features.compose_email.create

    ticket = create_ticket({:status => 2, :source => 10, :email_config_id => @email_config.id})
    get :show, :id => ticket.display_id
    ticket.source..should = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:outbound_email]
    Delayed::Job.last.handler.should_not include("biz_rules_check")
    @account.features.compose_email.destroy
  end

  it "should create a meta for created by for phone tickets" do
    ticket = create_ticket({:status => 2, :source => 3})
    get :show, :id => ticket.display_id
    note = ticket.notes.find_by_source(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'])
    note.body.should_not be_nil
  end

  it "should not create a meta for created by if user and requester are the same" do
    user = FactoryGirl.build(:user,:name => "new_user_contact", :account => @acc, :phone => Faker::PhoneNumber.phone_number, 
                                    :email => Faker::Internet.email, :user_role => 3, :active => true, :customer_id => company.id)
    user.save
    user.make_current
    ticket = create_ticket({:status => 2, :source => 3, :requester_id => user.id})
    get :show, :id => ticket.display_id
    note = ticket.notes.find_by_source(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'])
    note.should be_nil
  end


  it "should create a meta for created by for portal tickets" do
    ticket = create_ticket({:status => 2, :source => 2})
    get :show, :id => ticket.display_id
    note = ticket.notes.find_by_source(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'])
    note.should_not be_nil
  end

  # Added this test case for covering note_actions.rb and attachment_helper.rb
  it "should view a ticket with notes(having to_emails & attachments)" do
    file = fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)
    ticket = create_ticket({:status => 2},@group)
    agent_details = "#{@agent.name} #{@agent.email}"
    note = ticket.notes.build(
        :to_emails =>[agent_details],
        :note_body_attributes => {:body => Faker::Lorem.sentence },
        :private => true,
        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'],
        :account_id => ticket.account.id,
        :user_id => ticket.requester.id
    )
    note.attachments.build(:content => file, 
                           :description => Faker::Lorem.characters(10) , 
                           :account_id => note.account_id)
    note.save_note
    get :show, :id => ticket.display_id
    response.body.should =~ /#{ticket.description_html}/
  end

  # Following 2 tests are added to cover survey models
  it "should load the reply template with survey link" do
    @account.survey.update_attributes(:send_while => 1)
    notification = @account.email_notifications.find_by_notification_type(EmailNotification::COMMENTED_BY_AGENT)
    notification.update_attributes(:requester_notification => true,
                                   :requester_template => "#{notification.requester_template} {{ticket.satisfaction_survey}}")
    ticket = create_ticket
    get :show, :id => ticket.display_id
    response.body.should =~ /#{ticket.description_html}/
  end

  it "should show the survey remark of a ticket" do
    Survey::CUSTOMER_RATINGS.each do |rating_type, value|
      ticket = create_ticket({ :status => 2 }, @group)
      note = ticket.notes.build({:note_body_attributes => {:body => Faker::Lorem.sentence}, :user_id => @agent.id})
      note.save_note
      send_while = rand(1..4)
      s_handle = create_survey_handle(ticket, send_while, note)
      s_handle.create_survey_result rating_type
      remark = Faker::Lorem.sentence
      s_handle.survey_result.add_feedback(remark)
      s_handle.destroy
      s_result = s_handle.survey_result
      s_remark = SurveyRemark.find_by_survey_result_id(s_result.id)
      s_remark.should be_an_instance_of(SurveyRemark)
      note = ticket.notes.last
      s_remark.note_id.should be_eql(note.id)
      note.body.should be_eql(remark)

      get :show, :id => ticket.display_id
      response.body.should =~ /#{ticket.description_html}/
    end
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

  it "should create a new outbound email ticket" do
    now = (Time.now.to_f*1000).to_i
    @account.features.compose_email.create
    post :create, :helpdesk_ticket => {:email => Faker::Internet.email,
                                       :requester_id => "",
                                       :subject => "New Oubound Ticket #{now}",
                                       :ticket_type => "Question",
                                       :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:outbound_email],
                                       :status => "2",
                                       :priority => "1",
                                       :group_id => "",
                                       :responder_id => "",
                                       :cc_email => ["someone@cc.com", "somenew@cc.com"],
                                       :email_config_id => @email_config.id,
                                       :ticket_body_attributes => {"description_html"=>"<p>Testing</p>"}
                                      }
    Delayed::Job.last.handler.should_not include("biz_rules_check")                                  
    t = @account.tickets.find_by_subject("New Oubound Ticket #{now}")
    t.cc_email[:cc_email].include?("someone@cc.com")
    t.source.should be_eql(Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:outbound_email])
    @account.tickets.find_by_subject("New Oubound Ticket #{now}").should be_an_instance_of(Helpdesk::Ticket)
    @account.features.compose_email.destroy
  end

  it "should create a new outbound email ticket for non feature account but outbound email check should return false" do
    now = (Time.now.to_f*1000).to_i
    post :create, :helpdesk_ticket => {:email => Faker::Internet.email,
                                       :requester_id => "",
                                       :subject => "New Oubound Ticket #{now}",
                                       :ticket_type => "Question",
                                       :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:outbound_email],
                                       :status => "2",
                                       :priority => "1",
                                       :group_id => "",
                                       :responder_id => "",
                                       :email_config_id => @email_config.id,
                                       :ticket_body_attributes => {"description_html"=>"<p>Testing</p>"}
                                      }
    Delayed::Job.last.handler.should_not include("biz_rules_check")
    t = @account.tickets.find_by_subject("New Oubound Ticket #{now}")
    t.source.should be_eql(Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:outbound_email])
    t.outbound_email?.should be false
    @account.tickets.find_by_subject("New Oubound Ticket #{now}").should be_an_instance_of(Helpdesk::Ticket)

  end

  it "should create a new ticket with RabbitMQ enabled" do
    RabbitMq::Keys::TICKET_SUBSCRIBERS = ["auto_refresh"]
    RABBIT_MQ_ENABLED = true
    Account.any_instance.stubs(:rabbit_mq_exchange).returns([])
    Array.any_instance.stubs(:publish).returns(true)
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
    RABBIT_MQ_ENABLED = false
    Account.any_instance.unstub(:rabbit_mq_exchange)
    Array.any_instance.unstub(:publish)
  end

  it "should create a new ticket with RabbitMQ enabled and with RabbitMq publish error" do
    RabbitMq::Keys::TICKET_SUBSCRIBERS = ["auto_refresh"]
    RABBIT_MQ_ENABLED = true
    Account.any_instance.stubs(:rabbit_mq_exchange).returns([])
    Array.any_instance.stubs(:publish).raises(StandardError)
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
    RABBIT_MQ_ENABLED = false
    Account.any_instance.unstub(:rabbit_mq_exchange)
    Array.any_instance.unstub(:publish)
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

    it "should update a ticket's properties with agent collision feature" do
      @account.features.agent_collision.create
      test_ticket = create_ticket
      put :update_ticket_properties, { :helpdesk_ticket => { :priority => "4",
                                                             :status => "3",
                                                             :source => "9",
                                                             :ticket_type => "Lead",
                                                             :group_id => "",
                                                             :responder_id => ""
                                                            },
                                       :helpdesk => { :tags => ""},
                                       :id => test_ticket.display_id
                                      }
      @account.features.agent_collision.destroy
      updated_ticket = @account.tickets.find(test_ticket.id)
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

    it "should not update the due date of a ticket" do
      ticket =  @account.tickets.find(@test_ticket.id)
      old_due_date = ticket.due_by.to_date
      new_due_date = (Time.now - 4000.years).to_date.strftime("%a %b %d %Y %H:%M:%S")
      put :change_due_by, { :due_date_options => "specific",
                            :due_by_hour => "3",
                            :due_by_minute => "00",
                            :due_by_am_pm => "PM",
                            :due_by_date_time => new_due_date,
                            :id => @test_ticket.display_id
                          }
      ticket.due_by.to_date.should_not be_eql(new_due_date.to_date)
      ticket.due_by.to_date.should be_eql(old_due_date.to_date)
    end

    it "should save draft for a ticket" do
      draft_key = HELPDESK_REPLY_DRAFTS % { :account_id => @account.id, :user_id => @agent.id,
        :ticket_id => @test_ticket.id}
      post :save_draft, { :draft_data => "<p>Testing save_draft</p>",
                          :draft_cc => "ccemail@email.com",
                          :draft_bcc => "bccemail@email.com",
                          :id => @test_ticket.display_id }
      draft_hash = get_tickets_redis_hash_key(draft_key)
      if draft_hash
        draft_message = draft_hash["draft_data"]
        draft_cc = draft_hash["draft_cc"]
        draft_bcc = draft_hash["draft_bcc"]
        draft_message.should be_eql("<p>Testing save_draft</p>")
        draft_cc.should be_eql("ccemail@email.com")
        draft_bcc.should be_eql("bccemail@email.com")
      else
        fail "Draft hash is nil"
      end
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
      picked_tickets.include?(pick_ticket1.id).should be_truthy
      picked_tickets.include?(pick_ticket2.id).should be_truthy
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
      assigned_tickets.include?(assign_ticket1.id).should be_truthy
      assigned_tickets.include?(assign_ticket2.id).should be_truthy
    end

    it "should close multiple tickets" do
      close_ticket1 = create_ticket({ :status => 2 }, @group)
      close_ticket2 = create_ticket({ :status => 2 }, @group)
      @request.env['HTTP_REFERER'] = 'sessions/new'
      put :close_multiple, { :id => "multiple",
                             :ids => ["#{close_ticket1.display_id}", "#{close_ticket2.display_id}"]}
      closed_tickets = @account.tickets.find_all_by_status(5).map(&:id)
      closed_tickets.include?(close_ticket1.id).should be_truthy
      closed_tickets.include?(close_ticket2.id).should be_truthy
    end

    it "should mark multiple tickets as spam" do
      spam_ticket1 = create_ticket({ :status => 2 }, @group)
      spam_ticket2 = create_ticket({ :status => 2 }, @group)
      @request.env['HTTP_REFERER'] = 'sessions/new'
      put :spam, { :id => "multiple",
                   :ids => ["#{spam_ticket1.display_id}", "#{spam_ticket2.display_id}"]}
      spammed_tickets = @account.tickets.find_all_by_spam(1).map(&:id)
      spammed_tickets.include?(spam_ticket1.id).should be_truthy
      spammed_tickets.include?(spam_ticket2.id).should be_truthy
    end

    it "should delete multiple tickets" do
      del_ticket1 = create_ticket({ :status => 2 }, @group)
      del_ticket2 = create_ticket({ :status => 2 }, @group)
      delete :destroy, { :id => "multiple",
                         :ids => ["#{del_ticket1.display_id}", "#{del_ticket2.display_id}"]}
      deleted_tickets = @account.tickets.find_all_by_deleted(1).map(&:id)
      deleted_tickets.include?(del_ticket1.id).should be_truthy
      deleted_tickets.include?(del_ticket2.id).should be_truthy
    end


  # Spam and Delete

    it "should mark a ticket as spam" do
      put :spam, :id => @test_ticket.display_id
      @account.tickets.find(@test_ticket.id).spam.should be_truthy
    end

    it "should delete a ticket" do
      delete :destroy, :id => @test_ticket.display_id
      @account.tickets.find(@test_ticket.id).deleted.should be_truthy
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
      @account.tickets.find(tkt1.id).spam.should be false
      @account.tickets.find(tkt2.id).spam.should be false
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
      (assigns(:items).include? ticket_created).should be_truthy
      (response.body.include? created_at_timestamp).should be_truthy
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
      (assigns(:items).include? ticket_created).should be_truthy
      (response.body.include? created_at_timestamp).should be_truthy
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
      (assigns(:items).include? ticket_created).should be_truthy
      (response.body.include? created_at_timestamp).should be_truthy
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
      (assigns(:items).include? ticket_created).should be_truthy
      (response.body.include? created_at_timestamp).should be_truthy
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
      (assigns(:items).include? ticket_created).should be_truthy
      (response.body.include? created_at_timestamp).should be_truthy
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
      (assigns(:items).include? ticket_created).should be_truthy
      (response.body.include? created_at_timestamp).should be_truthy
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
      (assigns(:items).include? ticket_created).should be_truthy
      (response.body.include? created_at_timestamp).should be_truthy
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
      response.should render_template "helpdesk/tickets/customview/_new"
    end

    it "should return new tickets page through topic" do
      forum_category = create_test_category
      forum = create_test_forum(forum_category)
      topic = create_test_topic(forum)
      publish_topic(topic)
      get :new , {"topic_id" => topic.id }
      response.should render_template "helpdesk/tickets/new"
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
      response.should render_template "helpdesk/shared/_ticket_overlay"
      response.body.should =~ /#{body}/
      tkt2 = create_ticket({ :status => 2 }, @group)
      tkt2.reload
      get :latest_note , :id => tkt2.display_id
      response.should render_template "helpdesk/shared/_ticket_overlay"
      response.body.should =~ /#{tkt2.description}/
    end

    it "should load the next and previous tickets of a ticket" do # failing in master
      ticket_1 = create_ticket
      ticket_2 = create_ticket
      ticket_3 = create_ticket
      get :index
      response.should render_template "helpdesk/tickets/index"
      get :prevnext, :id => ticket_2.display_id
      assigns(:previous_ticket).to_i.should eql ticket_3.display_id
      assigns(:next_ticket).to_i.should eql ticket_1.display_id
    end

    it "should load the next ticket of a ticket from the adjacent page" do# TODO-RAILS3 failing on master also
      get :index
      response.should render_template "helpdesk/tickets/index"
      ticket = assigns(:items).first
      30.times do |i|
        create_ticket
      end
      get :index
      response.should render_template "helpdesk/tickets/index"
      last_ticket = assigns(:items).last
      get :prevnext, :id => last_ticket.display_id
      assigns(:next_ticket).to_i.should eql ticket.display_id
    end

    it "should load the next and previous tickets of a ticket with no filters" do# failing in master
      30.times do |i|
        t = create_ticket
      end
      @request.cookies['filter_name'] = "0"
      get :index
      response.should render_template "helpdesk/tickets/index"
      last_ticket = assigns(:items).last
      remove_tickets_redis_key(HELPDESK_TICKET_FILTERS % {:account_id => @account.id, 
                                                          :user_id => @agent.id, 
                                                          :session_id => request.session_options[:id]})
      get :prevnext, :id => last_ticket.display_id
      assigns(:previous_ticket).to_i.should eql last_ticket.display_id + 1
    end


    # Empty Trash
    it "should empty(delete) all tickets in trash view" do
      tkt1 = create_ticket({ :status => 2 }, @group)
      tkt2 = create_ticket({ :status => 2 }, @group)
      delete_tkt_arr = []
      delete_tkt_arr.push(tkt1.display_id.to_s, tkt2.display_id.to_s)
      delete :destroy, :id => "multiple", :ids => delete_tkt_arr
      Resque.inline = true
      delete :empty_trash
      Resque.inline = false
      @account.tickets.find_by_id(tkt1.id).should be_nil
      @account.tickets.find_by_id(tkt2.id).should be_nil
    end
    
    # Ticket actions
    it "should split the note and as ticket" do
      tkt = create_ticket({ :status => 2})
      @account.reload
      tickets_count = @account.tickets.count
      note_body = Faker::Lorem.sentence
      note = tkt.notes.build({ :note_body_attributes => {:body => note_body} , :user_id => tkt.requester_id, 
                               :incoming => true, :private => false})
      note.save_note
      post :split_the_ticket, { :id => tkt.display_id,
          :note_id => note.id
      }
      tkt.notes.find_by_id(note.id).should be_nil
      ticket_incremented? tickets_count
      @account.tickets.last.ticket_body.description_html.should =~ /#{note_body}/
    end

    it "should close a ticket" do
      tkt = create_ticket({ :status => 2 }, @group)
      post :close, :id => tkt.display_id
      tkt.reload
      @account.tickets.find_by_id(tkt.id).status.should be_eql(5)
    end

    it "should clear the filter_ticket values and set new values from tags" do
      ticket = create_ticket({ :status => 2}, @group)
      tag = ticket.tags.create(:name=> "Tag - #{Faker::Name.name}", :account_id =>@account.id)
      get :index, :tag_name => tag.name, :tag_id => tag.id
      response.body.should =~ /#{ticket.subject}/
      response.body.should =~ /##{ticket.display_id}/
      response.body.should =~ /#{tag.name}/
    end

    it "should clear the filter_ticket values and set new values from company page" do
      company = create_company
      user = FactoryGirl.build(:user,:name => "new_user_contact", :account => @acc, :phone => Faker::PhoneNumber.phone_number, 
                                    :email => Faker::Internet.email, :user_role => 3, :active => true, :customer_id => company.id)
      user.save
      ticket = create_ticket({ :status => 2, :requester_id => user.id}, @group)
      ticket_1 = create_ticket({ :status => 2}, @group)
      get :index, :company_id => company.id
      response.body.should =~ /#{company.name}/
      response.body.should =~ /#{ticket.subject}/
      response.body.should =~ /##{ticket.display_id}/
      response.body.should_not =~ /#{ticket_1.subject}/
    end

    it "should clear the filter_ticket values and set new values from contact page" do
      user = add_test_agent(@account)
      ticket_1 = create_ticket({ :status => 2, :requester_id => user.id}, @group)
      ticket_2 = create_ticket({ :status => 2}, @group)
      get :index, :requester_id => user.id
      response.body.should =~ /#{user.name}/
      response.body.should =~ /#{ticket_1.subject}/
      response.body.should =~ /##{ticket_1.display_id}/
      response.body.should_not =~ /#{ticket_2.subject}/
    end

    it "should render add_requester page" do
      post :add_requester
      response.should render_template 'contacts/_add_requester_form'
      response.should be_success
    end

    it "should return the paginated values" do
      ticket_1 = create_ticket({ :status => 2}, @group)
      ticket_2 = create_ticket({ :status => 2}, @group)
      tag = ticket_1.tags.create(:name=> "Tag - #{Faker::Name.name}", :account_id =>@account.id)
      tag_uses = FactoryGirl.build(:tag_uses, :tag_id => tag.id, :taggable_type => "Helpdesk::Ticket", :taggable_id=> ticket_2.id)
      tag_uses.save(:validate => false)
      get 'index', :tag_name => tag.name, :tag_id => tag.id
      tickets_count = @account.tags.find(tag.id).tag_uses_count
      get :full_paginate
      assigns["ticket_count"].should eql tickets_count
      response.should be_success
    end

    it "should configure the export" do
      get :configure_export
      response.should render_template 'helpdesk/tickets/_configure_export'
      response.body.should =~ /Export as/
      response.body.should =~ /Filter tickets by/
    end

    it "should export a ticket csv file" do 
      create_ticket({ :status => 2, :requester_id => @agent.id, :subject => Faker::Lorem.sentence(4) })
      create_ticket({ :status => 5, :requester_id => @agent.id, :subject => Faker::Lorem.sentence(4) })

      start_date = Date.parse((Time.now - 2.day).to_s).strftime("%d %b, %Y");
      end_date = Date.parse((Time.now).to_s).strftime("%d %b, %Y");

      Resque.inline = true
      post :export_csv, :data_hash => "[]", :format => "csv", :ticket_state_filter=>"created_at",
                        :date_filter => 30, :start_date => "#{start_date}",
                        :end_date => "#{end_date}", :export_fields => { :display_id => "Ticket Id",
                                                                        :subject => "Subject",
                                                                        :description => "Description",
                                                                        :status_name => "Status",
                                                                        :requester_name => "Requester Name",
                                                                        :requester_info => "Requester Email",
                                                                        :responder_name => "Agent",
                                                                        :created_at => "Created Time",
                                                                        :updated_at => "Last Updated Time"
                        }
      Resque.inline = false
      response.content_type.to_s.should be_eql("text/html")
      response.headers['Content-Type'].should eql("text/html; charset=utf-8")
      session[:flash][:notice].should eql"Your Ticket data will be sent to your email shortly!"
    end

    it "should render assign tickets to agent page" do
      post :assign_to_agent
      response.should render_template 'helpdesk/tickets/_assign_agent'
      response.should be_success
    end

    it "should render update_multiple_tickets page" do
      get :update_multiple_tickets
      response.should render_template 'helpdesk/tickets/_update_multiple'
      response.should be_success
    end

    it "should render component page" do
      ticket = create_ticket({ :status => 2}, @group)
      get :component, :component => "ticket_fields", :id => ticket.id
      assigns["ticket"].id.should eql ticket.id
      response.should render_template 'helpdesk/tickets/show/_ticket_fields'
      response.should be_success
    end
  
  it "should split the fb comment to a ticket, move all its child notes and update all the attributes of the old ticket" do
    Resque.inline = true
    
    ticket, note = create_fb_tickets
    
    
    post :split_the_ticket, { :id => ticket.display_id,
          :note_id => note.id
      }
      
    ticket.notes.find_by_id(note.id).should be_nil
    new_ticket = @account.tickets.last
    new_ticket.notes.count.should eql 1
    new_ticket.activities.count.should eql 2
    
    Resque.inline = false
  end
  # test cases for bulk scenario automations starts here
  it "should render scenarios page" do
    get :bulk_scenario, :bulk_scenario => true
    response.should render_template "helpdesk/tickets/show/_scenarios"
    response.should be_success
  end

  it "should execute a scenario for multiple tickets" do
    Sidekiq::Testing.inline!
    @request.env['HTTP_REFERER'] = 'sessions/new'
    scenario_ticket1 = create_ticket({ :status => 2 }, @group)
    scenario_ticket2 = create_ticket({ :status => 2 }, @group)
    user = Account.current.users.find_by_id(1)
    user.make_current
    scenario = @account.scn_automations.find_by_name("Mark as Feature Request")
    put :execute_bulk_scenario, :scenario_id => scenario.id, :ids => ["#{scenario_ticket1.display_id}","#{scenario_ticket2.display_id}"],:user_id => "1"
    @account.tickets.find(scenario_ticket1.id).ticket_type.should be_eql("Feature Request")
    @account.tickets.find(scenario_ticket2.id).ticket_type.should be_eql("Feature Request")
    Sidekiq::Testing.disable!
  end
  # test cases for bulk scenario automations ends here
end
