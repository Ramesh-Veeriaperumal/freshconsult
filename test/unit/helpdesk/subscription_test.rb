require 'test_helper'

class Helpdesk::SubscriptionTest < ActiveSupport::TestCase
  should_belong_to :ticket, :user
  should_have_index :user_id, :ticket_id
end
