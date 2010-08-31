require 'test_helper'

class Helpdesk::ReminderTest < ActiveSupport::TestCase
  should_belong_to :user, :ticket
  should_have_named_scope :visible
  should_have_index :user_id, :ticket_id
  should_ensure_length_in_range :body, (1..120) 

end
