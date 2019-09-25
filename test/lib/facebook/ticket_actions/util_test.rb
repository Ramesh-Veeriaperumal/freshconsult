require_relative '../../../test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')

class TicketActionsUtilTest < ActionView::TestCase
  include AccountHelper
  include Facebook
  include TicketActions
  include Util
  include Facebook::TicketActions::Util

  def setup
    super
    before_all
    Channel::CommandWorker.jobs.clear
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account = create_test_account
    @@before_all_run = true
  end

  def teardown
    super
  end

  def test_publish_command_to_central_error
    old_count = Channel::CommandWorker.jobs.size
    TicketActionsUtilTest.any_instance.stubs(:sandbox).returns([nil, nil, nil])
    response = send_reply(nil, nil, nil, 'comment')
    new_count = Channel::CommandWorker.jobs.size
    assert_equal old_count, new_count
    assert_equal nil, response
  end
end
