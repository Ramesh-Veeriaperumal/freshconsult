require 'test_helper'

class Helpdesk::TagUseTest < ActiveSupport::TestCase
  should_belong_to :tags, :tickets
  should_have_index :ticket_id, :tag_id
  should_validate_uniqueness_of :tag_id, :scoped_to => :ticket_id
  should_validate_numericality_of :ticket_id, :tag_id

end
