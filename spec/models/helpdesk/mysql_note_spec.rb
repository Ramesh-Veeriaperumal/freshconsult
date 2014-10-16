require 'spec_helper'

describe Helpdesk::Note do

  self.use_transactional_fixtures = false

  before(:all) do
    $primary_cluster = "mysql"
    $secondary_cluster = "none"
    $backup_cluster = "none"
    @account.make_current
    @user = User.find_by_account_id(@account.id)
    @ticket =  Helpdesk::Ticket.new(
      :requester_id => @user.id,
      :subject => "test note one",
      :ticket_body_attributes => {
        :description => "test",
        :description_html => "<div>test</div>"
      }
    )
    @ticket.save_ticket
  end

  describe "Note Creation" do
    context "creats note_body in mysql" do
      it "without body" do
        note = @ticket.notes.build(
          :user_id => @user.id
        )
        note.save_note
        note.note_body.body.should eql "Not given."
        note.note_body.body_html.should eql "<div>Not given.</div>"
        note.note_body.full_text.should eql "Not given."
        note.note_body.full_text_html.should eql "<div>Not given.</div>"
      end

      it "with note_body_attributes" do
        note = @ticket.notes.build(
          :user_id => @user.id,
          :note_body_attributes => {
            :body => "body two",
            :body_html => "<div>body two</div>"
        })
        note.save_note
        note.note_body.body.should eql "body two"
        note.note_body.body_html.should eql "<div>body two</div>"
        note.note_body.full_text.should eql "body two"
        note.note_body.full_text_html.should eql "<div>body two</div>"
      end

      it "with build_note_body" do
        note = @ticket.notes.build(
          :user_id => @user.id
        )
        note.build_note_body(
          :body_html => "<div>body two</div>"
        )
        note.save_note
        note.note_body.body.should eql "body two"
        note.note_body.body_html.should eql "<div>body two</div>"
        note.note_body.full_text.should eql "body two"
        note.note_body.full_text_html.should eql "<div>body two</div>"
      end

      it "rollbacks note_body both in riak and mysql" do
        note = @ticket.notes.build(
          :user_id => @user.id
        )
        note.build_note_body(
          :body => "body two",
          :body_html => "<div>body two</div>"
        )
        Riak::RObject.any_instance.stubs(:store).raises(ActiveRecord::Rollback, "Call tech support!")
        note.save_note
        # Helpdesk::Note.find_by_id(note.id).should be_nil
        Helpdesk::Note.find_by_id(note.id).body.should eql "body two"
      end
    end
  end

  describe "Note Edit/Update" do
    it "edits note_body in mysql" do
      note = @ticket.notes.build(
        :user_id => @user.id
      )
      note.build_note_body(
        :body => "body edit",
      )
      note.save_note
      note.update_note_attributes(
        :note_body_attributes => {
          :body_html => "<div>body edit updated</div>"
        }
      )
      note.note_body.body.should eql "body edit updated"
      note.note_body.body_html.should eql "<div>body edit updated</div>"
    end

    it "doesn't update note if note_body is not updated" do
      note = @ticket.notes.build(
        :user_id => @user.id,
      )
      note.build_ticket_body(
        :body => "description edit",
        :body_html => "<div>description edit</div>"
      )
      note.save_note
      note.note_body_content = nil
      Helpdesk::Note.any_instance.expects(:created_at_updated_at_on_update).never
      note.source = "5"
      note.save_note
    end
  end

  describe "Ticket Delete" do
    it "deletes note_body both in riak and mysql" do
      note = @ticket.notes.build(
        :user_id => @user.id
      )
      note.build_note_body(
        :body => "description edit",
        :body_html => "<div>description edit</div>"
      )
      note.save_note
      note_id = note.note_old_body
      note.destroy
      expect { $note_body.get("#{@account.id}/#{note.id}") }.to raise_error
      expect { Helpdesk::NoteOldBody.find("#{note_id}") }.to raise_error
    end
  end

  describe "Note Get" do
    it "get from mysql if present in only mysql and riak" do
      note = @ticket.notes.build(
        :user_id => @user.id,
        :note_body_attributes => {
          :body => "body three",
          :body_html => "<div>body three</div>"
      })
      note.save_note
      note.note_body_content = nil
      note_body = note.note_body
      note_body.class.should eql Helpdesk::NoteOldBody
      note_body.body.should eql "body three"
      note_body.body_html.should eql "<div>body three</div>"
      note.note_old_body.body.should eql "body three"
      note.note_old_body.body_html.should eql "<div>body three</div>"
    end

    it "return Helpdesk::TicketBody object if not present in both mysql and riak" do
      note = @ticket.notes.build(
        :user_id => @user.id
      )
      note_body = note.note_body
      note_body.class.should eql Helpdesk::NoteBody
      note_body.body.should be_nil
      note_body.body_html.should be_nil
    end
  end

end