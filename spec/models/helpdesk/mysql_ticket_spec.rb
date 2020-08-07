require 'spec_helper'

describe Helpdesk::Ticket do

  self.use_transactional_fixtures = false

  before(:all) do
    @user = User.find_by_account_id(@account.id)
  end

  describe "Ticket Creation" do
    context "creats ticket mysql" do
      it "without description" do
        ticket = Helpdesk::Ticket.new(
          :requester_id => @user.id,
          :subject => "test ticket one"
        )
        ticket.save_ticket
        ticket.ticket_body.description.should eql "Not given."
        ticket.ticket_body.description_html.should eql "<div>Not given.</div>"
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
        ticket.ticket_body.description.should eql "description two"
        ticket.ticket_body.description_html.should eql "<div>description two</div>"
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
        ticket.ticket_body.description.should eql "description two"
        ticket.ticket_body.description_html.should eql "<div>description two</div>"
      end
    end
  end

  describe "Ticket Edit/Update" do
    it "edits ticket_body both in mysql" do
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
      ticket.ticket_body.description.should eql "description edit updated"
      ticket.ticket_body.description_html.should eql "<div>description edit updated</div>"
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
      Helpdesk::Ticket.any_instance.expects(:created_at_updated_at_on_update).never
      ticket.subject = "test ticket one"
      ticket.save_ticket
    end
  end

  describe "Ticket Delete" do
    it "deletes ticket_body both in mysql" do
      ticket = Helpdesk::Ticket.new(
        :requester_id => @user.id,
        :subject => "test ticket two"
      )
      ticket.build_ticket_body(
        :description => "description edit",
        :description_html => "<div>description edit</div>"
      )
      ticket.save_ticket
      ticket_id = ticket.ticket_body
      ticket.destroy
      expect { Helpdesk::Ticket.find("#{ticket_id}") }.to raise_error
    end
  end


  describe "Ticket Get" do
    it "get from mysql" do
      ticket = Helpdesk::Ticket.new(
        :requester_id => @user.id,
        :subject => "test ticket three",
        :ticket_body_attributes => {
          :description => "description three",
          :description_html => "<div>description three</div>"
      })
      ticket.save_ticket
      ticket_body = ticket.ticket_body
      ticket_body.class.should eql Helpdesk::TicketBody
      ticket_body.description.should eql "description three"
      ticket_body.description_html.should eql "<div>description three</div>"
      ticket.ticket_body.description.should eql "description three"
      ticket.ticket_body.description_html.should eql "<div>description three</div>"
    end

    it "return Helpdesk::TicketBody object if not present in mysql" do
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
