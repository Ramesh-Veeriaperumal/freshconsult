require 'spec_helper'

RSpec.describe Helpdesk::MergeTicketsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    #@account = create_test_account
    @user = add_test_agent(@account)
    @group = create_group(@account, {:name => "Merge"})
    @target_ticket = create_ticket({ :status => 2}, @group)
  end

  before(:each) do
    login_admin
    @source_ticket1 = create_ticket({ :status => 2 }, @group)
    @source_ticket2 = create_ticket({ :status => 2 }, @group)
    #stub_s3_writes
  end

  after(:each) do
    @source_ticket1.destroy
    @source_ticket2.destroy
  end

  it "should bulk_merge all tickets" do
    post :bulk_merge, { :source_tickets => ["#{@target_ticket.display_id}","#{@source_ticket1.display_id}", "#{@source_ticket2.display_id}"],
                        :redirect_back => "true"
    }
    response.body.should =~ /(Conversations from the merged tickets will be added to the primary ticket)/
    response.body.should =~ /#{@target_ticket.subject}/
    response.body.should =~ /#{@source_ticket1.subject}/
    response.body.should =~ /#{@source_ticket1.display_id}/
    response.body.should =~ /#{@source_ticket2.display_id}/
  end

  it "should merge all tickets" do
    post :merge, { :target => { :ticket_id => @target_ticket.display_id },
                   :source_tickets => ["#{@source_ticket1.display_id}", "#{@source_ticket2.display_id}"],
                   :format => 'js'
    }
    response.should be_success
    response.body.should =~ /Confirm and merge/
    response.body.should =~ /#{@target_ticket.display_id}/
    response.body.should =~ /#{@source_ticket1.subject}/
    response.body.should =~ /#{@source_ticket1.display_id}/
    response.body.should =~ /#{@source_ticket2.subject}/
  end

  it "should merge tickets with private notes and time_sheets" do
    # Creating a time sheet for @source_ticket1
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => @agent.id,
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
                            :redirect_back => "true"
                          }
    Resque.inline = false
    flash[:notice] =~ /have been merged into the ticket/
    merged_tickets = @account.tickets.find([@target_ticket.id, @source_ticket1.id, @source_ticket2.id])
    last_target_note = merged_tickets[0].notes.last
    last_target_note.full_text.should be_eql("Tickets with ids #{@source_ticket1.display_id} and #{@source_ticket2.display_id} are merged into this ticket.")
    last_target_note.private.should be true
    merged_tickets[1].status.should be_eql(5)
    last_source1_note = merged_tickets[1].notes.last
    last_source1_note.full_text.should be_eql("This ticket is closed and merged into ticket #{@target_ticket.display_id}")
    last_source1_note.private.should be true
    merged_tickets[2].status.should be_eql(5)
    last_source2_note = merged_tickets[2].notes.last
    last_source2_note.full_text.should be_eql("This ticket is closed and merged into ticket #{@target_ticket.display_id}")
    last_source2_note.private.should be true

    # check if time_sheet workable_id have been updated to target_ticket_id
    @account.time_sheets.find(time_sheet.id).workable_id.should eql @target_ticket.id
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
                            :redirect_back => "true"
                          }
    Resque.inline = false
    merged_tickets = @account.tickets.find([@target_ticket.id, @source_ticket1.id, @source_ticket2.id])
    last_target_note = merged_tickets[0].notes.last
    last_target_note.full_text.should be_eql("Tickets with ids #{@source_ticket1.display_id} and #{@source_ticket2.display_id} are merged into this ticket.")
    last_target_note.private.should be false
    merged_tickets[1].status.should be_eql(5)
    last_source1_note = merged_tickets[1].notes.last
    last_source1_note.full_text.should be_eql("This ticket is closed and merged into ticket #{@target_ticket.display_id}")
    last_source1_note.private.should be false
    merged_tickets[2].status.should be_eql(5)
    last_source2_note = merged_tickets[2].notes.last
    last_source2_note.full_text.should be_eql("This ticket is closed and merged into ticket #{@target_ticket.display_id}")
    last_source2_note.private.should be false
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
                            :redirect_back => "true"
                          }
    Resque.inline = false
    merged_tickets = @account.tickets.find([@target_ticket.id, @source_ticket1.id, @source_ticket2.id])
    last_target_note = merged_tickets[0].notes.last
    last_target_note.full_text.should be_eql("Tickets with ids #{@source_ticket1.display_id} and #{@source_ticket2.display_id} are merged into this ticket.")
    last_target_note.private.should be true
    merged_tickets[1].status.should be_eql(5)
    last_source1_note = merged_tickets[1].notes.last
    last_source1_note.full_text.should be_eql("This ticket is closed and merged into ticket #{@target_ticket.display_id}")
    last_source1_note.private.should be false
    merged_tickets[2].status.should be_eql(5)
    last_source2_note = merged_tickets[2].notes.last
    last_source2_note.full_text.should be_eql("This ticket is closed and merged into ticket #{@target_ticket.display_id}")
    last_source2_note.private.should be false
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
                            :redirect_back => "true"
                          }
    Resque.inline = false
    target_ticket.reload
    first_target_note_id = target_ticket.notes.first.id
    note_attchment = @account.attachments.find_by_attachable_id(first_target_note_id)
    note_attchment.should_not be_nil
    note_attchment.attachable_type.should eql "Helpdesk::Note"
  end

  it "should merge tickets with header_info" do
    ids = ["newreply@gamil.com","replynote@gamil.com"]
    @target_ticket.header_info = {:message_ids => [ids[0]]}
    @target_ticket.save(:validate => false)
    @source_ticket2.header_info = {:message_ids => [ids[1]]}
    @source_ticket2.save(:validate => false)

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
                            :redirect_back => "true"
                          }
    Resque.inline = false

    # Check if source_ticket2 message have been merged to target_ticket_schema(After merge)
    @target_ticket.reload
    @target_ticket.schema_less_ticket.text_tc01[:message_ids].should include(ids[1])
  end
end
