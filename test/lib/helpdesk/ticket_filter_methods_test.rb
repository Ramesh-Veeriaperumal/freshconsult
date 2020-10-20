require_relative '../../api/unit_test_helper'

class TicketFilterMethodsTest < ActionView::TestCase
  include Helpdesk::TicketFilterMethods

  def setup
    Account.stubs(:current).returns(Account.first)
    User.stubs(:current).returns(Account.current.users.first)
  end

  def teardown
    Account.unstub(:current)
    User.unstub(:current)
    super
  end

  def params
    {
      report_type: Faker::Lorem.word,
      filter_name: 'archived'
    }
  end

  def privilege?(params)
    params.nil?
  end

  def current_account
    Account.first
  end

  def current_user
    current_account.users.first
  end

  def test_top_views
    assert_not_nil top_views('new_and_my_open', [{ id: 1, user_id: current_user.id, name: Faker::Lorem.word }])
    assert_not_nil top_views('new_and_my_open', [{ id: '1', user_id: current_user.id, name: Faker::Lorem.word }])
    assert_not_nil top_views(Faker::Lorem.word)
  end

  def test_links_displayed_properly
    assert_not_nil save_link(nil)
    assert_not_nil cancel_link(id: 'archived')
    assert_not_nil save_as_link(nil)
    assert_not_nil edit_link(nil)
    assert_not_nil delete_link(id: 'archived')
    assert_equal filter_path(id: 'archived'), '/helpdesk/tickets/archived'
  end

  def test_filter_details
    assert_nil current_filter_title
    assert_not_nil get_ticket_show_params({ 'action' => 'save', 'controller' => 'Helpdesk::Ticket', 'page' => '10' }, current_account.tickets.first.display_id)
    assert_not_nil get_ticket_show_params({}, current_account.tickets.first.display_id)
  end

  def test_filter_params
    Search::Filters::Docs.any_instance.stubs(:count).returns(1)
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    assert_not_nil filter_count
    assert_not_nil filter_count(nil, true)
    assert_not_nil filter_count(nil, true)
    Account.any_instance.stubs(:launched?).returns(true)
    ActiveRecord::Relation.any_instance.stubs(:count).returns(1)
    assert_equal filter_count(nil, true), 1
    assert_not_nil current_agent_mode
    assert_not_nil current_group_mode
    assert_not_nil current_wf_order
    assert_not_nil current_wf_order_type
    assert_not_nil filter_select
  ensure
    Search::Filters::Docs.any_instance.unstub(:count)
    Account.any_instance.unstub(:shared_ownership_enabled?)
    Account.any_instance.unstub(:launched?)
    ActiveRecord::Relation.any_instance.unstub(:count)
  end
end
