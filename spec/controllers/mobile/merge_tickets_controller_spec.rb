require 'spec_helper'

describe Helpdesk::MergeTicketsController do
  self.use_transactional_fixtures = false

  before(:all) do
    #@account = create_test_account
    @user = add_test_agent(@account)
    @group = create_group(@account, {:name => "Merge"})
    @target_ticket = create_ticket({ :status => 2}, @group)
  end

  before(:each) do
    api_login
    @source_ticket1 = create_ticket({ :status => 2 }, @group)
    @source_ticket2 = create_ticket({ :status => 2 }, @group)
  end

  after(:each) do
    @source_ticket1.destroy
    @source_ticket2.destroy
  end

  it "should merge tickets with private notes and time_sheets" do
    # Creating a time sheet for @source_ticket1
    time_sheet = Factory.build(:time_sheet, :user_id => @agent.id,
                                            :workable_id => @source_ticket1.id,
                                            :account_id => @account.id,
                                            :billable => 1,
                                            :note => "tkt timer")
    time_sheet.save
    Resque.inline = true
    post :complete_merge, { :target => { :ticket_id => @target_ticket.display_id,
                                          :note => "Tickets with ids #{@source_ticket1.display_id} and #{@source_ticket2.display_id} are merged into this ticket.",
                                          :is_private => "true"
                                          },
                            :source_tickets => ["#{@source_ticket1.display_id}", "#{@source_ticket2.display_id}"],
                            :source => { :note => "This ticket is closed and merged into ticket #{@target_ticket.display_id}",
                                         :is_private => "true"
                                        },
                            :format => 'json'
                          }
    Resque.inline = false
    json_response["result"].should be_true
    json_response["count"].should be_eql(2)
    end

  it "should merge tickets with public notes" do
    Resque.inline = true
    post :complete_merge, { :target => { :ticket_id => @target_ticket.display_id,
                                          :note => "Tickets with ids #{@source_ticket1.display_id} and #{@source_ticket2.display_id} are merged into this ticket.",
                                          :is_private => "false"
                                          },
                            :source_tickets => ["#{@source_ticket1.display_id}", "#{@source_ticket2.display_id}"],
                            :source => { :note => "This ticket is closed and merged into ticket #{@target_ticket.display_id}",
                                         :is_private => "false"
                                        },
                            :format => 'json'
                          }
    Resque.inline = false                      
    json_response["result"].should be_true
    json_response["count"].should be_eql(2)
  end

  it "should merge tickets with public notes for the source tickets" do
    Resque.inline = true
    post :complete_merge, { :target => { :ticket_id => @target_ticket.display_id,
                                          :note => "Tickets with ids #{@source_ticket1.display_id} and #{@source_ticket2.display_id} are merged into this ticket.",
                                          :is_private => "true"
                                          },
                            :source_tickets => ["#{@source_ticket1.display_id}", "#{@source_ticket2.display_id}"],
                            :source => { :note => "This ticket is closed and merged into ticket #{@target_ticket.display_id}",
                                         :is_private => "false"
                                        },
                            :format => 'json'
                          }
    Resque.inline = false                      
    json_response["result"].should be_true
    json_response["count"].should be_eql(2)
  end

  it "should merge tickets with attachments" do
    # Creating a ticket with attachment
    target_ticket = create_ticket({ :status => 2}, @group)
    source_ticket2 = create_ticket({:status => 2,
                                    :attachments => {:resource => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary),
                                                      :description => Faker::Lorem.characters(10)
                                                      }
                                    }, @group) 
    Resque.inline = true
    post :complete_merge, { :target => { :ticket_id => target_ticket.display_id,
                                          :note => "Tickets with ids #{@source_ticket1.display_id} and #{source_ticket2.display_id} are merged into this ticket.",
                                          :is_private => "false"
                                          },
                            :source_tickets => ["#{@source_ticket1.display_id}", "#{source_ticket2.display_id}"],
                            :source => { :note => "This ticket is closed and merged into ticket #{target_ticket.display_id}",
                                         :is_private => "false"
                                        },
                            :format => 'json'
                          }
    Resque.inline = false
    json_response["result"].should be_true
    json_response["count"].should be_eql(2)
  end

  it "should merge tickets with header_info" do
    ids = ["newreply@gamil.com","replynote@gamil.com"]
    @target_ticket.header_info = {:message_ids => [ids[0]]}
    @target_ticket.save(false)
    @source_ticket2.header_info = {:message_ids => [ids[1]]}
    @source_ticket2.save(false)

    # Before merge
    @target_ticket.schema_less_ticket.text_tc01[:message_ids].should_not include(ids[1])
    
    Resque.inline = true
    post :complete_merge, { :target => { :ticket_id => @target_ticket.display_id,
                                          :note => "Tickets with ids #{@source_ticket1.display_id} and #{@source_ticket2.display_id} are merged into this ticket.",
                                          :is_private => "false"
                                          },
                            :source_tickets => ["#{@source_ticket1.display_id}", "#{@source_ticket2.display_id}"],
                            :source => { :note => "This ticket is closed and merged into ticket #{@target_ticket.display_id}",
                                         :is_private => "false"
                                        },
                            :format => 'json'
                          }
    Resque.inline = false

    json_response["result"].should be_true
    json_response["count"].should be_eql(2)
  end
end
