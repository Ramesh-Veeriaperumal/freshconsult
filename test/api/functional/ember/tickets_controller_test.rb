require_relative '../../test_helper'
['ticket_helper.rb', 'group_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module Ember
  class TicketsControllerTest < ActionController::TestCase
    include GroupHelper
    include TicketHelper

    def test_spam_with_invalid_ticket_id
      put :spam, construct_params({ version: 'private' }, false).merge(id: 0)
      assert_response 404
    end

    def test_spam_with_unauthorized_ticket_id
      @sample_ticket = create_ticket
      User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
      User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
      User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
      put :spam, construct_params({ version: 'private' }, false).merge(id: @sample_ticket.id)
      User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end

    def test_spam_with_valid_ticket_id
      @sample_ticket = create_ticket
      assert !@sample_ticket.spam?
      put :spam, construct_params({ version: 'private' }, false).merge(id: @sample_ticket.id)
      assert_response 204
      assert @sample_ticket.reload.spam?
    end
  end
end