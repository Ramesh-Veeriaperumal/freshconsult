require 'test_helper'

class Helpdesk::NoteTest < ActiveSupport::TestCase

  should_belong_to :notable, :user
  should_have_many :attachments
  should_have_named_scope :newest_first
  should_have_named_scope :visible
  should_have_named_scope :public
  should_have_named_scope :freshest
  should_have_index :notable_id
  should_validate_presence_of :body, :source, :notable_id
  should_validate_numericality_of :source
  should_ensure_value_in_range :source, (0..Helpdesk::Note::SOURCES.size - 1) 
  should_not_allow_mass_assignment_of :attachments, :notable_id

  should "Have required contants" do
    assert Helpdesk::Note::SOURCES
  end

  should "return notes for active tickets, newest first, when Note.freshest called" do
    prev = nil
    Helpdesk::Note.freshest.each do |note|
      assert prev.created_at >= note.created_at if prev
      assert !note.deleted
      prev = note
    end
  end
end
