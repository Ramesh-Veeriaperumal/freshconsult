require 'spec_helper'

describe Helpdesk::Ticket do

  self.use_transactional_fixtures = false

  before(:all) do
    @user = User.find_by_account_id(@account.id)
    unless RIAK_ENABLED
      $primary_cluster = "mysql"
      $secondary_cluster = "none"
      $backup_cluster = "none"
    else
      $primary_cluster = "riak"
      $secondary_cluster = "mysql"
      $backup_cluster = "none"
    end
  end

  describe "Ticket Creation" do
    context "creats ticket_body both in riak and mysql" do
      it "without description" do
        ticket = Helpdesk::Ticket.new(
          :requester_id => @user.id,
          :subject => "test ticket one"
        )
        ticket.save_ticket
        if RIAK_ENABLED
          riak_ticket_body = ticket.read_from_riak
          riak_ticket_body.description.should eql "Not given."
          riak_ticket_body.description_html.should eql "<div>Not given.</div>"
        end
        riak_ticket_body = ticket.read_from_mysql
        riak_ticket_body.description.should eql "Not given."
        riak_ticket_body.description_html.should eql "<div>Not given.</div>"
      end

      it "with ticket_body_attributes" do
        ticket = Helpdesk::Ticket.new(
          :requester_id => @user.id,
          :subject => "test ticket two",
          :ticket_body_attributes => {
            :description => "description two",
            :description_html => "<div>description two</div>"
        })
        ticket.save_ticket
        if RIAK_ENABLED
          riak_ticket_body = ticket.read_from_riak
          riak_ticket_body.description.should eql "description two"
          riak_ticket_body.description_html.should eql "<div>description two</div>"
        end
        riak_ticket_body = ticket.read_from_mysql
        riak_ticket_body.description.should eql "description two"
        riak_ticket_body.description_html.should eql "<div>description two</div>"
      end

      it "with build_ticket_body" do
        ticket = Helpdesk::Ticket.new(
          :requester_id => @user.id,
          :subject => "test ticket two"
        )
        ticket.build_ticket_body(
          :description => "description two",
          :description_html => "<div>description two</div>"
        )
        ticket.save_ticket
        if RIAK_ENABLED
          riak_ticket_body = ticket.read_from_riak
          riak_ticket_body.description.should eql "description two"
          riak_ticket_body.description_html.should eql "<div>description two</div>"
        end
        riak_ticket_body = ticket.read_from_mysql
        riak_ticket_body.description.should eql "description two"
        riak_ticket_body.description_html.should eql "<div>description two</div>"
      end

      it "rollbacks doesn't happens if riak throws a exception" do
        ticket = Helpdesk::Ticket.new(
          :requester_id => @user.id,
          :subject => "test ticket two"
        )
        ticket.build_ticket_body(
          :description => "description two",
          :description_html => "<div>description two</div>"
        )
        if RIAK_ENABLED
          Riak::RObject.any_instance.stubs(:store).raises(ActiveRecord::Rollback, "Call tech support!")
        end
        ticket.save_ticket
        # Helpdesk::Ticket.find_by_id(ticket.id).should be_nil
        Helpdesk::Ticket.find_by_id(ticket.id).description.should eql "description two"
      end
    end
  end

  describe "Ticket Edit/Update" do
    it "edits ticket_body both in riak and mysql" do
      ticket = Helpdesk::Ticket.new(
        :requester_id => @user.id,
        :subject => "test ticket two"
      )
      ticket.build_ticket_body(
        :description => "description edit",
        :description_html => "<div>description edit</div>"
      )
      ticket.save_ticket
      ticket.update_ticket_attributes(
        :ticket_body_attributes => {
          :description_html => "<div>description edit updated</div>"
        }
      )
      if RIAK_ENABLED
        riak_ticket_body = ticket.read_from_riak
        riak_ticket_body.description.should eql "description edit updated"
        riak_ticket_body.description_html.should eql "<div>description edit updated</div>"
      end
      riak_ticket_body = ticket.read_from_mysql
      riak_ticket_body.description.should eql "description edit updated"
      riak_ticket_body.description_html.should eql "<div>description edit updated</div>"
    end

    it "rollbacks both in riak and mysql" do
        ticket = Helpdesk::Ticket.new(
          :requester_id => @user.id,
          :subject => "test ticket two"
        )
        ticket.build_ticket_body(
          :description => "description two",
          :description_html => "<div>description two</div>"
        )
        ticket.save_ticket
        ticket.update_ticket_attributes(
          :ticket_body_attributes => {
            :description_html => "<div>description three</div>"
            }
        )
        if RIAK_ENABLED
          riak_ticket_body = ticket.read_from_riak
          riak_ticket_body.description.should eql "description three"
          riak_ticket_body.description_html.should eql "<div>description three</div>"
        end
        riak_ticket_body = ticket.read_from_mysql
        riak_ticket_body.description.should eql "description three"
        riak_ticket_body.description_html.should eql "<div>description three</div>"
        Helpdesk::Ticket.any_instance.expects(:created_at_updated_at_on_update).raises(ActiveRecord::Rollback, "Call tech support!")
        ticket.update_ticket_attributes(
          :ticket_body_attributes => {
            :description_html => "<div>description four</div>"
            }
        )
        if RIAK_ENABLED
          riak_ticket_body = ticket.read_from_riak
          riak_ticket_body.description.should eql "description three"
          riak_ticket_body.description_html.should eql "<div>description three</div>"
        end
        riak_ticket_body = ticket.read_from_mysql
        riak_ticket_body.description.should eql "description three"
        riak_ticket_body.description_html.should eql "<div>description three</div>"
    end

    it "doesn't update ticket_body if ticket is updated" do
      ticket = Helpdesk::Ticket.new(
        :requester_id => @user.id,
        :subject => "test ticket two"
      )
      ticket.build_ticket_body(
        :description => "description edit",
        :description_html => "<div>description edit</div>"
      )
      ticket.save_ticket
      ticket.ticket_body_content = nil
      Helpdesk::Ticket.any_instance.expects(:created_at_updated_at_on_update).never
      ticket.subject = "test ticket one"
      ticket.save_ticket
    end
  end

  describe "Ticket Delete" do
    it "deletes ticket_body both in riak and mysql" do
      ticket = Helpdesk::Ticket.new(
        :requester_id => @user.id,
        :subject => "test ticket two"
      )
      ticket.build_ticket_body(
        :description => "description edit",
        :description_html => "<div>description edit</div>"
      )
      ticket.save_ticket
      ticket_id = ticket.ticket_old_body
      ticket.destroy
      if RIAK_ENABLED
        expect { $ticket_body.get("#{@account.id}/#{ticket.id}") }.to raise_error
      end
      expect { Helpdesk::TicketOldBody.find("#{ticket_id}") }.to raise_error
    end

    it "rollbacks both in riak and mysql" do
      ticket = Helpdesk::Ticket.new(
        :requester_id => @user.id,
        :subject => "test ticket two"
      )
      ticket.build_ticket_body(
        :description => "description delete",
        :description_html => "<div>description delete</div>"
      )
      ticket.save_ticket
      if RIAK_ENABLED
        Riak::Bucket.any_instance.stubs(:delete).raises(ActiveRecord::Rollback, "Call tech support!")
      end
      ticket.destroy
      if RIAK_ENABLED
        riak_ticket_body = ticket.read_from_riak
        riak_ticket_body.description.should eql "description delete"
        riak_ticket_body.description_html.should eql "<div>description delete</div>"
      end
      riak_ticket_body = ticket.read_from_mysql
      riak_ticket_body.description.should eql "description delete"
      riak_ticket_body.description_html.should eql "<div>description delete</div>"
      if RIAK_ENABLED
        Riak::Bucket.any_instance.unstub(:delete)
      end
    end
  end


  describe "Ticket Get" do
    it "get from riak if present in both mysql and riak" do
      ticket = Helpdesk::Ticket.new(
        :requester_id => @user.id,
        :subject => "test ticket two",
        :ticket_body_attributes => {
          :description => "description two",
          :description_html => "<div>description two</div>"
      })
      ticket.save_ticket
      ticket.ticket_body_content = nil
      if RIAK_ENABLED
        Riak::RContent.any_instance.expects(:data).with().returns(
          {"ticket_body"=>
           {"description"=>"description two",
            "description_html"=>"<div>description two</div>",
            "meta_info"=>nil,
            "raw_html"=>nil,
            "raw_text"=>nil,
            "version"=>nil
            }
           }).once
      end
      ticket.ticket_body
      ticket.destroy
    end

    it "get from mysql if present only in mysql" do
      ticket = Helpdesk::Ticket.new(
        :requester_id => @user.id,
        :subject => "test ticket three",
        :ticket_body_attributes => {
          :description => "description three",
          :description_html => "<div>description three</div>"
      })
      ticket.save_ticket
      ticket.ticket_body_content = nil
      if RIAK_ENABLED
        Riak::Bucket.any_instance.stubs(:get).raises(Riak::ProtobuffsFailedRequest.new("",""))
      end
      ticket_old_body_object = Helpdesk::TicketOldBody.find_by_ticket_id(ticket.id)
      ticket_body = ticket.ticket_body
      ticket_body.class.should eql Helpdesk::TicketOldBody
      ticket_body.description.should eql "description three"
      ticket_body.description_html.should eql "<div>description three</div>"
      ticket.ticket_old_body.description.should eql "description three"
      ticket.ticket_old_body.description_html.should eql "<div>description three</div>"
    end

    it "return Helpdesk::TicketBody object if not present in both mysql and riak" do
      ticket = Helpdesk::Ticket.new(
        :requester_id => @user.id,
        :subject => "test ticket three"
      )
      ticket_body = ticket.ticket_body
      ticket_body.class.should eql Helpdesk::TicketBody
      ticket_body.description.should be_nil
      ticket_body.description_html.should be_nil
    end
  end

end
