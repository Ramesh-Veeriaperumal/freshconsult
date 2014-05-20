require 'spec_helper'

describe Helpdesk::TicketsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @group_name = "Tickets - #{Time.now}"
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => @group_name}))
    @group = @account.groups.find_by_name(@group_name)
    @test_group = create_group(@account, {:name => "Group-Bulk -Test #{Time.now}"})
  end

  before(:each) do
    log_in(@user)
  end

  it "should not create a new ticket without the required fields" do
    now = (Time.now.to_f*1000).to_i
    post :create, :helpdesk_ticket => {:email => "",
                                       :requester_id => "", 
                                       :subject => "#{now}", 
                                       :ticket_type => "Question", 
                                       :source => "3", 
                                       :status => "2", 
                                       :priority => "1", 
                                       :group_id => "", 
                                       :responder_id => "", 
                                       :ticket_body_attributes => {"description_html"=>"<p>Testing</p>"}
                                      }
    response.body.should =~ /Requester should be a valid email address/
    @account.tickets.find_by_subject("#{now}").should be_nil
  end

  # Restricted access - global tickets props should not change where as tickets assined to restricted user should change..
  # Close -restricted access

  it "should not allow a restricted agent to close other agents' tickets" do
    restricted_user = add_agent(@account, { :name => Faker::Name.name, 
                                            :email => Faker::Internet.email, 
                                            :active => 1, 
                                            :role => 1, 
                                            :agent => 1,
                                            :ticket_permission => 3,
                                            :role_ids => ["#{@account.roles.first.id}"] })
    global_agent_ticket = create_ticket({ :status => 2 }, @group)
    global_agent_ticket.update_attributes(:responder_id => @user.id)
    restricted_agent_ticket= create_ticket({ :status => 2 }, @group)
    restricted_agent_ticket.update_attributes(:responder_id =>restricted_user.id)
    log_in(restricted_user)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :close_multiple, { :id => "multiple", :ids => [global_agent_ticket.display_id,restricted_agent_ticket.display_id] }
    @account.tickets.find(global_agent_ticket.id).status.should be_eql(2)
    @account.tickets.find(restricted_agent_ticket.id).status.should be_eql(5)
  end

  # Delete -restricted access

  it "should not allow a restricted agent to delete other agent's tickets" do
    restricted_user = add_agent(@account, { :name => Faker::Name.name, 
                                            :email => Faker::Internet.email, 
                                            :active => 1, 
                                            :role => 1, 
                                            :agent => 1,
                                            :ticket_permission => 3,
                                            :role_ids => ["#{@account.roles.first.id}"] })
    global_agent_ticket = create_ticket({ :status => 2 }, @group)
    global_agent_ticket.update_attributes(:responder_id => @user.id)
    restricted_agent_ticket= create_ticket({ :status => 2 }, @group)
    restricted_agent_ticket.update_attributes(:responder_id =>restricted_user.id)
    log_in(restricted_user)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :destroy, { :id => "multiple", :ids => [global_agent_ticket.display_id,restricted_agent_ticket.display_id] }
    @account.tickets.find(global_agent_ticket.id).deleted.should be_eql(false)
    @account.tickets.find(restricted_agent_ticket.id).deleted.should be_eql(true)
  end

  # Empty trash -restricted access

  it "should not allow a restricted agent to delete other agent's tickets forever" do
    restricted_user = add_agent(@account, { :name => Faker::Name.name, 
                                            :email => Faker::Internet.email, 
                                            :active => 1, 
                                            :role => 1, 
                                            :agent => 1,
                                            :ticket_permission => 3,
                                            :role_ids => ["#{@account.roles.first.id}"] })
    global_agent_ticket = create_ticket({ :status => 2 }, @group)
    global_agent_ticket.update_attributes(:responder_id => @user.id,:deleted => true)
    restricted_agent_ticket= create_ticket({ :status => 2 }, @group)
    restricted_agent_ticket.update_attributes(:responder_id => restricted_user.id ,:deleted => true)
    log_in(restricted_user)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    Resque.inline = true
    put :delete_forever, { :id => "multiple", :ids => [global_agent_ticket.display_id,restricted_agent_ticket.display_id] }
    Resque.inline = false
    @account.tickets.find_by_id(global_agent_ticket.id).should_not be_nil
    @account.tickets.find_by_id(restricted_agent_ticket.id).should be_nil
  end

  # Assign -restricted access

  it "should not allow a restricted agent to assign tickets to others" do
    restricted_user = add_agent(@account, { :name => Faker::Name.name, 
                                            :email => Faker::Internet.email, 
                                            :active => 1, 
                                            :role => 1, 
                                            :agent => 1,
                                            :ticket_permission => 3,
                                            :role_ids => ["#{@account.roles.first.id}"] })
    responder_user = add_agent(@account, { :name => Faker::Name.name, 
                                            :email => Faker::Internet.email, 
                                            :active => 1, 
                                            :role => 1, 
                                            :agent => 1,
                                            :ticket_permission => 1,
                                            :role_ids => ["#{@account.roles.first.id}"] })
    global_agent_ticket = create_ticket({ :status => 2 }, @group)
    global_agent_ticket.update_attributes(:responder_id => @user.id)
    restricted_agent_ticket= create_ticket({ :status => 2 }, @group)
    restricted_agent_ticket.update_attributes(:responder_id =>restricted_user.id)
    log_in(restricted_user)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :assign, { :id => "multiple", :responder_id=>responder_user.id,:ids => [global_agent_ticket.display_id,restricted_agent_ticket.display_id] }
    @account.tickets.find(global_agent_ticket.id).responder_id.should be_eql(@user.id)
    @account.tickets.find(restricted_agent_ticket.id).responder_id.should be_eql(responder_user.id)
  end

  # Pickup Tickets -restricted access

  it "should not allow a restricted agent to pickup tickets " do
    restricted_user = add_agent(@account, { :name => Faker::Name.name, 
                                            :email => Faker::Internet.email, 
                                            :active => 1, 
                                            :role => 1, 
                                            :agent => 1,
                                            :ticket_permission => 3,
                                            :role_ids => ["#{@account.roles.first.id}"] })
    global_agent_ticket = create_ticket({ :status => 2 }, @group)
    global_agent_ticket.update_attributes(:responder_id => @user.id)
    log_in(restricted_user)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :pick_tickets, { :id => "multiple", :ids => [global_agent_ticket.display_id] }
    @account.tickets.find(global_agent_ticket.id).responder_id.should be_eql(@user.id)    
  end

  # Flag spam -restricted access

  it "should not allow a restricted agent to mark tickets as spam" do
    restricted_user = add_agent(@account, { :name => Faker::Name.name, 
                                            :email => Faker::Internet.email, 
                                            :active => 1, 
                                            :role => 1, 
                                            :agent => 1,
                                            :ticket_permission => 3,
                                            :role_ids => ["#{@account.roles.first.id}"] })
    global_agent_ticket = create_ticket({ :status => 2 }, @group)
    global_agent_ticket.update_attributes(:responder_id => @user.id)
    restricted_agent_ticket= create_ticket({ :status => 2 }, @group)
    restricted_agent_ticket.update_attributes(:responder_id =>restricted_user.id)
    log_in(restricted_user)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :spam, { :id => "multiple", :ids => [global_agent_ticket.display_id,restricted_agent_ticket.display_id] }
    @account.tickets.find(global_agent_ticket.id).spam.should be_eql(false)
    @account.tickets.find(restricted_agent_ticket.id).spam.should be_eql(true)
  end

  # Group access - global tickets props should not change where as tickets assigned to group user, tickets in that group should change
  # Close -group access

  it "should not allow a group agent to close other agents' tickets" do
    group_user = add_agent(@account, { :name => Faker::Name.name, 
                                            :email => Faker::Internet.email, 
                                            :active => 1, 
                                            :role => 1, 
                                            :agent => 1,
                                            :ticket_permission => 2,
                                            :role_ids => ["#{@account.roles.first.id}"],
                                            :group_id => @test_group.id })
    global_agent_ticket = create_ticket({ :status => 2 }, @group)
    global_agent_ticket.update_attributes(:responder_id => @user.id)
    restricted_agent_ticket= create_ticket({ :status => 2 }, @group)
    restricted_agent_ticket.update_attributes(:responder_id =>group_user.id)
    group_agent_ticket =create_ticket({ :status => 2 },@test_group)
    group_agent_ticket.update_attributes(:responder_id => @user.id)
    log_in(group_user)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :close_multiple, { :id => "multiple", :ids => [global_agent_ticket.display_id,restricted_agent_ticket.display_id,group_agent_ticket.display_id] }
    @account.tickets.find(global_agent_ticket.id).status.should be_eql(2)
    @account.tickets.find(restricted_agent_ticket.id).status.should be_eql(5)
    @account.tickets.find(group_agent_ticket.id).status.should be_eql(5)
  end

  # Delete -group access

  it "should not allow a group agent to delete other agent's tickets" do
    group_user = add_agent(@account, { :name => Faker::Name.name, 
                                            :email => Faker::Internet.email, 
                                            :active => 1, 
                                            :role => 1, 
                                            :agent => 1,
                                            :ticket_permission => 2,
                                            :role_ids => ["#{@account.roles.first.id}"],
                                            :group_id => @test_group.id  })
    global_agent_ticket = create_ticket({ :status => 2 }, @group)
    global_agent_ticket.update_attributes(:responder_id => @user.id)
    restricted_agent_ticket= create_ticket({ :status => 2 }, @group)
    restricted_agent_ticket.update_attributes(:responder_id =>group_user.id)
    group_agent_ticket =create_ticket({ :status => 2 },@test_group)
    group_agent_ticket.update_attributes(:responder_id => @user.id)
    log_in(group_user)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :destroy, { :id => "multiple", :ids => [global_agent_ticket.display_id,restricted_agent_ticket.display_id,group_agent_ticket.display_id] }
    @account.tickets.find(global_agent_ticket.id).deleted.should be_eql(false)
    @account.tickets.find(restricted_agent_ticket.id).deleted.should be_eql(true)
    @account.tickets.find(group_agent_ticket.id).deleted.should be_eql(true)
  end

# Empty trash -group access

  it "should not allow a group agent to delete other agent's tickets forever" do
    group_user = add_agent(@account, { :name => Faker::Name.name, 
                                            :email => Faker::Internet.email, 
                                            :active => 1, 
                                            :role => 1, 
                                            :agent => 1,
                                            :ticket_permission => 2,
                                            :role_ids => ["#{@account.roles.first.id}"],
                                            :group_id => @test_group.id  })
    global_agent_ticket = create_ticket({ :status => 2 }, @group)
    global_agent_ticket.update_attributes(:responder_id => @user.id,:deleted => true)
    restricted_agent_ticket= create_ticket({ :status => 2 }, @group)
    restricted_agent_ticket.update_attributes(:responder_id =>group_user.id,:deleted =>true)
    group_agent_ticket =create_ticket({ :status => 2 },@test_group)
    group_agent_ticket.update_attributes(:responder_id => @user.id, :deleted =>true)
    log_in(group_user)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    Resque.inline = true
    put :delete_forever, { :id => "multiple", :ids => [global_agent_ticket.display_id,restricted_agent_ticket.display_id,group_agent_ticket.display_id] }
    Resque.inline = false
    @account.tickets.find_by_id(global_agent_ticket.id).should_not be_nil
    @account.tickets.find_by_id(restricted_agent_ticket.id).should be_nil
    @account.tickets.find_by_id(group_agent_ticket.id).should be_nil
  end

  # Assign -group access

  it "should not allow a group agent to assign tickets to others" do
    group_user = add_agent(@account, { :name => Faker::Name.name, 
                                            :email => Faker::Internet.email, 
                                            :active => 1, 
                                            :role => 1, 
                                            :agent => 1,
                                            :ticket_permission => 2,
                                            :role_ids => ["#{@account.roles.first.id}"],
                                            :group_id => @test_group.id  })
    responder_user = add_agent(@account, { :name => Faker::Name.name, 
                                            :email => Faker::Internet.email, 
                                            :active => 1, 
                                            :role => 1, 
                                            :agent => 1,
                                            :ticket_permission => 1,
                                            :role_ids => ["#{@account.roles.first.id}"] })
    global_agent_ticket = create_ticket({ :status => 2 }, @group)
    global_agent_ticket.update_attributes(:responder_id => @user.id)
    restricted_agent_ticket= create_ticket({ :status => 2 }, @group)
    restricted_agent_ticket.update_attributes(:responder_id =>group_user.id)
    group_agent_ticket =create_ticket({ :status => 2 },@test_group)
    group_agent_ticket.update_attributes(:responder_id => @user.id)
    log_in(group_user)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :assign, { :id => "multiple", :responder_id=>responder_user.id,:ids => [global_agent_ticket.display_id,restricted_agent_ticket.display_id,group_agent_ticket.display_id] }
    @account.tickets.find(global_agent_ticket.id).responder_id.should be_eql(@user.id)
    @account.tickets.find(restricted_agent_ticket.id).responder_id.should be_eql(responder_user.id)
    @account.tickets.find(group_agent_ticket.id).responder_id.should be_eql(responder_user.id)
  end

  # Pickup Tickets -group access

  it "should not allow a group agent to pickup tickets " do
    group_user = add_agent(@account, { :name => Faker::Name.name, 
                                            :email => Faker::Internet.email, 
                                            :active => 1, 
                                            :role => 1, 
                                            :agent => 1,
                                            :ticket_permission => 2,
                                            :role_ids => ["#{@account.roles.first.id}"],
                                            :group_id => @test_group.id  })
    global_agent_ticket = create_ticket({ :status => 2 }, @group)
    global_agent_ticket.update_attributes(:responder_id => @user.id)
    group_agent_ticket =create_ticket({ :status => 2 },@test_group)
    group_agent_ticket.update_attributes(:responder_id => @user.id)
    log_in(group_user)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :pick_tickets, { :id => "multiple", :ids => [global_agent_ticket.display_id,group_agent_ticket.display_id] }
    @account.tickets.find(global_agent_ticket.id).responder_id.should be_eql(@user.id)
    @account.tickets.find(group_agent_ticket.id).responder_id.should be_eql(group_user.id)
  end

  # Flag spam -group access

  it "should not allow a group agent to mark tickets as spam" do
    group_user = add_agent(@account, { :name => Faker::Name.name, 
                                            :email => Faker::Internet.email, 
                                            :active => 1, 
                                            :role => 1, 
                                            :agent => 1,
                                            :ticket_permission => 2,
                                            :role_ids => ["#{@account.roles.first.id}"] ,
                                            :group_id => @test_group.id })
    global_agent_ticket = create_ticket({ :status => 2 }, @group)
    global_agent_ticket.update_attributes(:responder_id => @user.id)
    restricted_agent_ticket= create_ticket({ :status => 2 }, @group)
    restricted_agent_ticket.update_attributes(:responder_id =>group_user.id)
    group_agent_ticket =create_ticket({ :status => 2 },@test_group)
    group_agent_ticket.update_attributes(:responder_id => @user.id)
    log_in(group_user)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :spam, { :id => "multiple", :ids => [global_agent_ticket.display_id,restricted_agent_ticket.display_id,group_agent_ticket.display_id] }
    @account.tickets.find(global_agent_ticket.id).spam.should be_eql(false)
    @account.tickets.find(restricted_agent_ticket.id).spam.should be_eql(true)
    @account.tickets.find(group_agent_ticket.id).spam.should be_eql(true)
  end

end