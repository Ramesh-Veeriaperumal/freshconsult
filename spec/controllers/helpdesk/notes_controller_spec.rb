require 'spec_helper'

describe Helpdesk::NotesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({:status => 2 })
    @ticket_note = create_note({:source => @test_ticket.source,
                               :ticket_id => @test_ticket.id,
                               :body => Faker::Lorem.paragraph,
                               :user_id => @agent.id})
  end

  before(:each) do
    log_in(@agent)
  end

  it "should create a note and go to index page(show activities)" do
    test_ticket = create_ticket({:status => 2 })
    body = "New note shown on index"
    post :create, :helpdesk_note => { :note_body_attributes => {:body_html => "<p>#{body}</p>"} },
                  :ticket_id => test_ticket.display_id

    test_ticket.reload
    test_ticket.notes.exclude_source('meta').freshest(@account).last.body.should =~ /#{body}/

    get :index, :v => 2, :ticket_id => test_ticket.display_id, :format => "json"
    response.body.should =~ /New note shown on index/

  end

  it "should create a note and go to index page(show activities) with xhr request" do
    test_ticket = create_ticket({:status => 2 })
    body = "New note shown on index"

    post :create, :helpdesk_note => { :note_body_attributes => {:body_html => "<p>#{body}</p>"} },
                  :ticket_id => test_ticket.display_id, :showing => "activities", :since_id => "-1"

    test_ticket.notes.exclude_source('meta').freshest(@account).last.body.should =~ /#{body}/
    xhr :get, :index, :v => 2, :ticket_id => test_ticket.display_id
    response.body.should =~ /New note shown on index/
    response.should render_template "helpdesk/tickets/show/_conversations"
  end

  it "should create a note with RabbitMQ enabled" do
    RabbitMq::Keys::NOTE_SUBSCRIBERS = ["auto_refresh"]
    RABBIT_MQ_ENABLED = true
    Account.any_instance.stubs(:rabbit_mq_exchange).returns([])
    Array.any_instance.stubs(:publish).returns(true)

    test_ticket = create_ticket({:status => 2 })
    now = (Time.now.to_f*1000).to_i
    post :create, :helpdesk_note => { :note_body_attributes => {:body_html => "<p>#{now}</p>"} },
                  :ticket_id => test_ticket.display_id, :showing => "activities", :since_id => "-1"

    test_ticket.notes.exclude_source('meta').freshest(@account).last.body.should =~ /#{now}/
    
    RABBIT_MQ_ENABLED = false
    Account.any_instance.unstub(:rabbit_mq_exchange)
    Array.any_instance.unstub(:publish)
  end

  it "should edit a note " do
    test_ticket = create_ticket({:status => 2 })
    body = Faker::Lorem.paragraph
    ticket_note = create_note({:source => test_ticket.source,
                               :ticket_id => test_ticket.id,
                               :body => body,
                               :user_id => @agent.id})
    get :edit, :ticket_id => test_ticket.display_id, :id => ticket_note.id
    response.body.should =~ /#{body}/
    response.should render_template "helpdesk/notes/_edit_note"
  end

  it "should update a note " do
    test_ticket = create_ticket({:status => 2 })
    body = Faker::Lorem.paragraph
    ticket_note = create_note({:source => test_ticket.source,
                               :ticket_id => test_ticket.id,
                               :body => body,
                               :user_id => @agent.id})

    updated_note_body = "Edited Note - #{Faker::Lorem.paragraph}"
    post :update, :helpdesk_note => {:source => @test_ticket.source,
                                    :note_body_attributes => { :body_html => updated_note_body,
                                                               :id => @ticket_note.id}},
                                    :id => @ticket_note.id,
                                    :ticket_id => @test_ticket.display_id
    @test_ticket.reload
    flash[:notice].should eql("The note has been updated.")
    @test_ticket.notes.last.body.should eql(updated_note_body)
  end

  it "should not update a note without source or ID" do
    now = (Time.now.to_f*1000).to_i
    updated_note_body = "#{now} - Edited Note - #{Faker::Lorem.paragraph}"
    post :update, :helpdesk_note => {:source => "",
                                    :note_body_attributes => { :body_html => updated_note_body,
                                                               :id => ""}},
                                    :id => @ticket_note.id,
                                    :ticket_id => @test_ticket.display_id
    @test_ticket.reload
    response.should render_template "helpdesk/notes/edit"
    @test_ticket.notes.last.body.should_not eql(updated_note_body)
  end

  it "should destroy a note " do
    test_ticket = create_ticket({:status => 2 })
    body = Faker::Lorem.paragraph
    ticket_note = create_note({:source => test_ticket.source,
                               :ticket_id => test_ticket.id,
                               :body => body,
                             :user_id => @agent.id})
    test_ticket.notes.last.body.should be_eql(body)
    post :destroy, :id => ticket_note.id, :ticket_id => test_ticket.display_id
    test_ticket.notes.last.deleted.should be_eql(true)
  end

  it "should destroy a note - Mobile format" do
    ticket_note = create_note({:source => @test_ticket.source,
                               :ticket_id => @test_ticket.id,
                               :body => Faker::Lorem.paragraph,
                               :user_id => @agent.id})
    @test_ticket.notes.last.deleted.should eql(false)
    post :destroy, :id => ticket_note.id, :ticket_id => @test_ticket.display_id, :format => 'mobile'
    @test_ticket.reload
    result = JSON.parse(response.body)
    result["success"].should be true
    @test_ticket.notes.last.deleted.should eql(true)
  end

  it "should destroy a note - Js format" do
    ticket_note = create_note({:source => @test_ticket.source,
                               :ticket_id => @test_ticket.id,
                               :body => Faker::Lorem.paragraph,
                               :user_id => @agent.id})
    @test_ticket.notes.last.deleted.should eql(false)
    post :destroy, :id => ticket_note.id, :ticket_id => @test_ticket.display_id, :format => 'js'
    @test_ticket.reload
    @test_ticket.notes.last.deleted.should eql(true)
  end

  it "should add a KBase article of ticket" do
   test_ticket = create_ticket({:status => 2 })
   now = (Time.now.to_f*1000).to_i
   post :create , { :reply_email => { :id => "support@#{@account.full_domain}"},
                   :helpdesk_note => { :cc_emails => ["kbase@#{@account.full_domain}"], 
                                       :note_body_attributes => {:body_html => "<div>#{now}</div>",
                                                                 :full_text_html => "<div>#{now}</div>"},
                                       :private => "0",
                                       :source => "0",
                                       :to_emails => "#{@agent.email}",
                                       :from_email => "support@#{@account.full_domain}",
                                       :bcc_emails => ""
                                      },
                   :ticket_status => "",
                   :ticket_id => test_ticket.display_id,
                   :since_id => "-1",
                   :showing => "activites"
                 } 
    @account.solution_articles.find_by_title(test_ticket.subject).should be_an_instance_of(Solution::Article)
  end

  it "should add a post to forum topic" do
    test_ticket = create_ticket({:status => 2 })
    category = create_test_category
    forum = create_test_forum(category)
    topic = create_test_topic(forum)
    create_ticket_topic_mapping(topic,test_ticket)
    now = (Time.now.to_f*1000).to_i
    body = "ticket topic note #{now}"
    post :create , { :reply_email => { :id => "support@#{@account.full_domain}"},
                   :helpdesk_note => { :cc_emails => "",
                                       :private => "0",
                                       :source => "0",
                                       :to_emails => "#{@agent.email}",
                                       :from_email => "support@#{@account.full_domain}",
                                       :bcc_emails => "",
                                       :body => "#{body}",
                                       :body_html => "<div>#{body}</div>",
                                      },
                   :ticket_status => "",
                   :ticket_id => test_ticket.display_id,
                   :since_id => "-1",
                   :post_forums => "1",
                   :showing => "notes"
                 } 
    topic.reload
    topic.last_post.body.strip.should eql(body)
  end
end
