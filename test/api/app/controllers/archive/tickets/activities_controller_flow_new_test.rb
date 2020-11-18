# frozen_string_literal: true

require_relative '../../../../api_test_helper'
['automations_test_helper.rb', 'archive_ticket_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

class Archive::Tickets::ActivitiesControllerFlowTest < ActionDispatch::IntegrationTest
  include ArchiveTicketTestHelper
  include ApiTicketsTestHelper
  include TicketHelper
  include ContactFieldsHelper
  include TicketActivitiesTestHelper
  include PrivilegesHelper
  include UsersTestHelper
  include AutomationTestHelper

  ARCHIVE_DAYS = 120

  def setup
    super
    @initial_private_api_request = CustomRequestStore.store[:private_api_request]
    CustomRequestStore.store[:private_api_request] = true
    @rule = create_service_task_observer_rule('1', 'same_ticket')
    @account.features.send(:archive_tickets).create
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true, requester_id: @agent.id)
    @ticket = @archive_ticket
    set_request_auth_headers
  end

  def teardown
    CustomRequestStore.store[:private_api_request] = @initial_private_api_request
    super
  end

  def test_activity_for_unavailable_ticket
    add_privilege(@agent, :manage_tickets)
    get '/api/_/tickets/archived/-10000/activities', { version: 'private' }, @write_headers
    assert_response 404
  end

  def test_activity_without_privilege
    remove_privilege(@agent, :manage_tickets)
    get "/api/_/tickets/archived/#{@archive_ticket.display_id}/activities", { version: 'private' }, @write_headers
    assert_response 403
  ensure
    @account.make_current
    add_privilege(@agent, :manage_tickets)
  end

  def test_activity_thrift_failure
    add_privilege(@agent, :manage_tickets)
    Archive::Tickets::ActivitiesController.any_instance.stubs(:fetch_activities).returns(false)
    get "/api/_/tickets/archived/#{@archive_ticket.display_id}/activities", { version: 'private' }, @write_headers
    assert_response 500
  ensure
    Archive::Tickets::ActivitiesController.unstub(:fetch_activities)
  end

  def test_property_update_activity
    add_privilege(@agent, :manage_tickets)
    stub_data = property_update_activity
    Archive::Tickets::ActivitiesController.any_instance.stubs(:fetch_activities).returns(stub_data)
    get "/api/_/tickets/archived/#{@archive_ticket.display_id}/activities", { version: 'private' }, @write_headers
    assert_response 200
  ensure
    Archive::Tickets::ActivitiesController.unstub(:fetch_activities)
  end

  def test_activity_with_restricted_hash
    add_privilege(@agent, :manage_tickets)
    stub_data = property_update_activity
    remove_privilege(@agent, :view_contacts)
    Archive::Tickets::ActivitiesController.any_instance.stubs(:fetch_activities).returns(stub_data)
    get "/api/_/tickets/archived/#{@archive_ticket.display_id}/activities", { version: 'private' }, @write_headers
    assert_response 200
  ensure
    @account.make_current
    add_privilege(@agent, :view_contacts)
    Archive::Tickets::ActivitiesController.unstub(:fetch_activities)
  end

  def test_invalid_fields_activity
    add_privilege(@agent, :manage_tickets)
    stub_data = invalid_fields_activity
    Archive::Tickets::ActivitiesController.any_instance.stubs(:fetch_activities).returns(stub_data)
    get "/api/_/tickets/archived/#{@archive_ticket.display_id}/activities", { version: 'private' }, @write_headers
    assert_response 200
  ensure
    Archive::Tickets::ActivitiesController.unstub(:fetch_activities)
  end
end
