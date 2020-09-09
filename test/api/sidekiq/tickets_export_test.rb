require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
require 'webmock/minitest'
WebMock.allow_net_connect!

Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('spec', 'support', 'agent_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'search_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'archive_ticket_test_helper.rb')

class TicketsExportTest < ActionView::TestCase
  include AgentHelper
  include CoreTicketsTestHelper
  include SearchTestHelper
  include ArchiveTicketTestHelper

  def setup
    super
    @account ||= Account.first
    @account.make_current
    @agent = @account.agents.first || add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1)
    datetime = Time.now
    @start_time = (datetime - 86400).to_s(:db)
    @end_time = datetime.to_s(:db)
    @time = (datetime - 1200).to_s(:db)
    @ticket_fields = { display_id: 'Ticket ID', subject: 'Subject', description: 'Description', status_name: 'Status', priority_name: 'Priority', source_name: 'Source', ticket_type: 'Type', responder_name: 'Agent', group_name: 'Group', created_at: 'Created time', due_by: 'Due by Time', resolved_at: 'Resolved time', closed_at: 'Closed time', updated_at: 'Last update time', first_response_time: 'Initial response time', time_tracked_hours: 'Time tracked', first_res_time_bhrs: 'First response time (in hrs)', resolution_time_bhrs: 'Resolution time (in hrs)', outbound_count: 'Agent interactions', inbound_count: 'Customer interactions', resolution_status: 'Resolution status', first_response_status: 'First response status', ticket_tags: 'Tags', ticket_survey_results: 'Survey results', product_name: 'Product' }
    stub_request(:post, %r{^http://scheduler-staging.freshworksapi.com/schedules.*?$}).to_return(status: 200, body: "", headers: {})
  end

  def test_index_ticket_csv
    @account.rollback(:silkroad_export)
    Tickets::Export::TicketsExport.any_instance.stubs(:send_to_silkroad?).returns(false)
    @ticket = create_ticket(requester_id: @agent.user_id, responder_id: @agent.user_id)
    @ticket.ticket_states.created_at = @time
    @ticket.ticket_states.save!
    args = { format: 'csv', date_filter: 30, ticket_state_filter: 'created_at',
             query_hash: [{ condition: 'created_at', operator: 'is_greater_than', value: 'last_month' }],
             start_date: @start_time, end_date: @end_time,
             ticket_fields: @ticket_fields,
             contact_fields: {},
             company_fields: {},
             filter_name: 'all_tickets',
             export_fields: { display_id: 'Ticket ID', subject: 'Subject', description: 'Description', status_name: 'Status', priority_name: 'Priority', source_name: 'Source', ticket_type: 'Type', responder_name: 'Agent', group_name: 'Group', created_at: 'Created time', due_by: 'Due by Time', resolved_at: 'Resolved time', closed_at: 'Closed time', updated_at: 'Last update time', first_response_time: 'Initial response time', time_tracked_hours: 'Time tracked', first_res_time_bhrs: 'First response time (in hrs)', resolution_time_bhrs: 'Resolution time (in hrs)', outbound_count: 'Agent interactions', inbound_count: 'Customer interactions', resolution_status: 'Resolution status', first_response_status: 'First response status', ticket_tags: 'Tags', ticket_survey_results: 'Survey results', product_name: 'Product' },
             data_hash: [{ condition: 'created_at', operator: 'is_greater_than', value: 'last_month' }, { condition: 'spam', operator: 'is', value: false }, { condition: 'deleted', operator: 'is', value: false }],
             current_user_id: @agent.user_id,
             portal_url: 'localhost.freshdesk-dev.com' }
    Export::Util.stubs(:build_attachment).returns(true)
    Tickets::Export::TicketsExport.new.perform(args)
    data_export = @account.data_exports.last
    assert_equal data_export.status, DataExport::EXPORT_STATUS[:completed]
    assert_equal data_export.source, DataExport::EXPORT_TYPE[:ticket]
    assert_equal data_export.last_error, nil
    data_export.destroy
    @ticket.destroy
  ensure
    Tickets::Export::TicketsExport.any_instance.unstub(:send_to_silkroad?)
    Export::Util.unstub(:build_attachment)
  end

  def test_index_ticket_excel
    @account.rollback(:silkroad_export)
    Tickets::Export::TicketsExport.any_instance.stubs(:send_to_silkroad?).returns(false)
    @ticket = create_ticket(requester_id: @agent.user_id, responder_id: @agent.user_id)
    @ticket.ticket_states.created_at = @time
    @ticket.ticket_states.save!
    args = { format: 'xls', date_filter: '30', ticket_state_filter: 'created_at',
             query_hash: [{ condition: 'created_at', operator: 'is_greater_than', value: 'last_month' }],
             start_date: @start_time, end_date: @end_time,
             ticket_fields: @ticket_fields,
             contact_fields: {},
             company_fields: {},
             filter_name: 'all_tickets',
             export_fields: { display_id: 'Ticket ID', subject: 'Subject', description: 'Description', status_name: 'Status', priority_name: 'Priority', source_name: 'Source', ticket_type: 'Type', responder_name: 'Agent', group_name: 'Group', created_at: 'Created time', due_by: 'Due by Time', resolved_at: 'Resolved time', closed_at: 'Closed time', updated_at: 'Last update time', first_response_time: 'Initial response time', time_tracked_hours: 'Time tracked', first_res_time_bhrs: 'First response time (in hrs)', resolution_time_bhrs: 'Resolution time (in hrs)', outbound_count: 'Agent interactions', inbound_count: 'Customer interactions', resolution_status: 'Resolution status', first_response_status: 'First response status', ticket_tags: 'Tags', ticket_survey_results: 'Survey results', product_name: 'Product' },
             data_hash: [{ condition: 'created_at', operator: 'is_greater_than', value: 'last_month' }, { condition: 'spam', operator: 'is', value: false }, { condition: 'deleted', operator: 'is', value: false }],
             current_user_id: @agent.user_id,
             portal_url: 'localhost.freshdesk-dev.com' }
    Export::Util.stubs(:build_attachment).returns(true)
    Tickets::Export::TicketsExport.new.perform(args)
    data_export = @account.data_exports.last
    p data_export.inspect
    assert_equal data_export.status, DataExport::EXPORT_STATUS[:completed]
    assert_equal data_export.source, DataExport::EXPORT_TYPE[:ticket]
    assert_equal data_export.last_error, nil
    data_export.destroy
    @ticket.destroy
  ensure
    Tickets::Export::TicketsExport.any_instance.unstub(:send_to_silkroad?)
    Export::Util.unstub(:build_attachment)
  end

  def test_index_associated_contact_csv
    @account.rollback(:silkroad_export)
    Tickets::Export::TicketsExport.any_instance.stubs(:send_to_silkroad?).returns(false)
    @ticket = create_ticket(requester_id: @agent.user_id, responder_id: @agent.user_id)
    @ticket.ticket_states.created_at = @time
    @ticket.ticket_states.save!
    args = { format: 'csv', date_filter: '30', ticket_state_filter: 'created_at',
             query_hash: [{ condition: 'status', operator: 'is_in', value: [2] }, { condition: 'responder_id', operator: 'is_in', value: ['-1', '0'] }],
             start_date: @start_time, end_date: @end_time,
             ticket_fields: @ticket_fields,
             contact_fields: { name: 'Full name', email: 'Email', phone: 'Work phone', mobile: 'Mobile phone', fb_profile_id: 'Facebook ID', twitter_id: 'Twitter ID', contact_id: 'Contact ID', time_zone: 'Time zone', language: 'Language', job_title: 'Title', unique_external_id: 'Unique External ID' },
             company_fields: {},
             filter_name: 'all_tickets',
             export_fields: { display_id: 'Ticket ID', subject: 'Subject', status_name: 'Status', priority_name: 'Priority', source_name: 'Source', ticket_type: 'Type', responder_name: 'Agent', group_name: 'Group', created_at: 'Created time', due_by: 'Due by Time', resolved_at: 'Resolved time', closed_at: 'Closed time', updated_at: 'Last update time', first_response_time: 'Initial response time', time_tracked_hours: 'Time tracked', first_res_time_bhrs: 'First response time (in hrs)', resolution_time_bhrs: 'Resolution time (in hrs)', outbound_count: 'Agent interactions', inbound_count: 'Customer interactions', resolution_status: 'Resolution status', first_response_status: 'First response status', ticket_tags: 'Tags', ticket_survey_results: 'Survey results', product_name: 'Product' },
             data_hash: [{ condition: 'status', operator: 'is_in', value: '2' }, { condition: 'responder_id', operator: 'is_in', value: '-1,0' }, { condition: 'spam', operator: 'is', value: false }, { condition: 'deleted', operator: 'is', value: false }],
             current_user_id: @agent.user_id,
             portal_url: 'localhost.freshdesk-dev.com' }
    Export::Util.stubs(:build_attachment).returns(true)
    Tickets::Export::TicketsExport.new.perform(args)
    data_export = @account.data_exports.last
    assert_equal data_export.status, DataExport::EXPORT_STATUS[:completed]
    assert_equal data_export.source, DataExport::EXPORT_TYPE[:ticket]
    assert_equal data_export.last_error, nil
    data_export.destroy
    @ticket.destroy
  ensure
    Tickets::Export::TicketsExport.any_instance.unstub(:send_to_silkroad?)
    Export::Util.unstub(:build_attachment)
  end

  def test_index_associated_company_csv
    @account.rollback(:silkroad_export)
    Tickets::Export::TicketsExport.any_instance.stubs(:send_to_silkroad?).returns(false)
    @ticket = create_ticket(requester_id: @agent.user_id, responder_id: @agent.user_id)
    @ticket.ticket_states.created_at = @time
    @ticket.ticket_states.save!
    args = { format: 'csv', date_filter: '30', ticket_state_filter: 'created_at',
             query_hash: [{ condition: 'status', operator: 'is_in', value: [2] }, { condition: 'responder_id', operator: 'is_in', value: ['-1', '0'] }],
             start_date: @start_time, end_date: @end_time,
             ticket_fields: @ticket_fields,
             contact_fields: {},
             company_fields: { name: 'Company Name', domains: 'Company Domains', health_score: 'Health score', account_tier: 'Account tier', industry: 'Industry', renewal_date: 'Renewal date' },
             filter_name: 'all_tickets',
             export_fields: { display_id: 'Ticket ID', subject: 'Subject', status_name: 'Status', priority_name: 'Priority', source_name: 'Source', ticket_type: 'Type', responder_name: 'Agent', group_name: 'Group', created_at: 'Created time', due_by: 'Due by Time', resolved_at: 'Resolved time', closed_at: 'Closed time', updated_at: 'Last update time', first_response_time: 'Initial response time', time_tracked_hours: 'Time tracked', first_res_time_bhrs: 'First response time (in hrs)', resolution_time_bhrs: 'Resolution time (in hrs)', outbound_count: 'Agent interactions', inbound_count: 'Customer interactions', resolution_status: 'Resolution status', first_response_status: 'First response status', ticket_tags: 'Tags', ticket_survey_results: 'Survey results', product_name: 'Product' },
             data_hash: [{ condition: 'status', operator: 'is_in', value: '2' }, { condition: 'responder_id', operator: 'is_in', value: '-1,0' }, { condition: 'spam', operator: 'is', value: false }, { condition: 'deleted', operator: 'is', value: false }],
             current_user_id: @agent.user_id,
             portal_url: 'localhost.freshdesk-dev.com' }
    Export::Util.stubs(:build_attachment).returns(true)
    Tickets::Export::TicketsExport.new.perform(args)
    data_export = @account.data_exports.last
    assert_equal data_export.status, DataExport::EXPORT_STATUS[:completed]
    assert_equal data_export.source, DataExport::EXPORT_TYPE[:ticket]
    assert_equal data_export.last_error, nil
    data_export.destroy
    @ticket.destroy
  ensure
    Tickets::Export::TicketsExport.any_instance.unstub(:send_to_silkroad?)
    Export::Util.unstub(:build_attachment)
  end

  def test_index_associated_contact_and_company_csv
    @account.rollback(:silkroad_export)
    Tickets::Export::TicketsExport.any_instance.stubs(:send_to_silkroad?).returns(false)
    @ticket = create_ticket(requester_id: @agent.user_id, responder_id: @agent.user_id)
    @ticket.ticket_states.created_at = @time
    @ticket.ticket_states.save!
    args = { format: 'csv', date_filter: '30', ticket_state_filter: 'created_at',
             query_hash: [{ condition: 'status', operator: 'is_in', value: [2] }, { condition: 'responder_id', operator: 'is_in', value: ['-1', '0'] }],
             start_date: @start_time, end_date: @end_time,
             ticket_fields: @ticket_fields,
             contact_fields: { name: 'Full name', email: 'Email', phone: 'Work phone', mobile: 'Mobile phone', fb_profile_id: 'Facebook ID', twitter_id: 'Twitter ID', contact_id: 'Contact ID', time_zone: 'Time zone', language: 'Language', job_title: 'Title', unique_external_id: 'Unique External ID' },
             company_fields: { name: 'Company Name', domains: 'Company Domains', health_score: 'Health score', account_tier: 'Account tier', industry: 'Industry', renewal_date: 'Renewal date' },
             filter_name: 'all_tickets',
             export_fields: { display_id: 'Ticket ID', subject: 'Subject', status_name: 'Status', priority_name: 'Priority', source_name: 'Source', ticket_type: 'Type', responder_name: 'Agent', group_name: 'Group', created_at: 'Created time', due_by: 'Due by Time', resolved_at: 'Resolved time', closed_at: 'Closed time', updated_at: 'Last update time', first_response_time: 'Initial response time', time_tracked_hours: 'Time tracked', first_res_time_bhrs: 'First response time (in hrs)', resolution_time_bhrs: 'Resolution time (in hrs)', outbound_count: 'Agent interactions', inbound_count: 'Customer interactions', resolution_status: 'Resolution status', first_response_status: 'First response status', ticket_tags: 'Tags', ticket_survey_results: 'Survey results', product_name: 'Product' },
             data_hash: [{ condition: 'status', operator: 'is_in', value: '2' }, { condition: 'responder_id', operator: 'is_in', value: '-1,0' }, { condition: 'spam', operator: 'is', value: false }, { condition: 'deleted', operator: 'is', value: false }],
             current_user_id: @agent.user_id,
             portal_url: 'localhost.freshdesk-dev.com' }
    Export::Util.stubs(:build_attachment).returns(true)
    Tickets::Export::TicketsExport.new.perform(args)
    data_export = @account.data_exports.last
    assert_equal data_export.status, DataExport::EXPORT_STATUS[:completed]
    assert_equal data_export.source, DataExport::EXPORT_TYPE[:ticket]
    assert_equal data_export.last_error, nil
    data_export.destroy
    @ticket.destroy
  ensure
    Tickets::Export::TicketsExport.any_instance.unstub(:send_to_silkroad?)
    Export::Util.unstub(:build_attachment)
  end

  def test_index_closed_csv
    @account.rollback(:silkroad_export)
    Tickets::Export::TicketsExport.any_instance.stubs(:send_to_silkroad?).returns(false)
    @ticket = create_ticket(requester_id: @agent.user_id, responder_id: @agent.user_id)
    args = { format: 'csv', date_filter: '0', ticket_state_filter: 'closed_at',
             query_hash: [{ condition: 'created_at', operator: 'is_greater_than', value: 'last_month' }],
             start_date: @start_time, end_date: @end_time,
             ticket_fields: @ticket_fields,
             contact_fields: {},
             company_fields: {},
             filter_name: 'all_tickets',
             export_fields: { display_id: 'Ticket ID', subject: 'Subject', description: 'Description', status_name: 'Status', priority_name: 'Priority', source_name: 'Source', ticket_type: 'Type', responder_name: 'Agent', group_name: 'Group', created_at: 'Created time', due_by: 'Due by Time', resolved_at: 'Resolved time', closed_at: 'Closed time', updated_at: 'Last update time', first_response_time: 'Initial response time', time_tracked_hours: 'Time tracked', first_res_time_bhrs: 'First response time (in hrs)', resolution_time_bhrs: 'Resolution time (in hrs)', outbound_count: 'Agent interactions', inbound_count: 'Customer interactions', resolution_status: 'Resolution status', first_response_status: 'First response status', ticket_tags: 'Tags', ticket_survey_results: 'Survey results', product_name: 'Product' },
             current_user_id: @agent.user_id,
             portal_url: 'localhost.freshdesk-dev.com' }
    @ticket.status = Helpdesk::Ticketfields::TicketStatus::CLOSED
    @ticket.save!
    @ticket.ticket_states.closed_at = @time
    @ticket.ticket_states.save!
    Export::Util.stubs(:build_attachment).returns(true)
    Tickets::Export::TicketsExport.new.perform(args)
    data_export = @account.data_exports.last
    assert_equal data_export.status, DataExport::EXPORT_STATUS[:completed]
    assert_equal data_export.source, DataExport::EXPORT_TYPE[:ticket]
    assert_equal data_export.last_error, nil
    data_export.destroy
    @ticket.destroy
  ensure
    Tickets::Export::TicketsExport.any_instance.unstub(:send_to_silkroad?)
    Export::Util.unstub(:build_attachment)
  end

  def test_tickets_export_with_silkroad_launched
    @account.launch(:silkroad_export)
    Tickets::Export::TicketsExport.any_instance.stubs(:send_to_silkroad?).returns(true)
    Silkroad::Export::Ticket.any_instance.stubs(:generate_headers).returns({})
    Silkroad::Export::Ticket.any_instance.stubs(:build_request_body).returns({})
    stub_request(:post, 'http://localhost:1728/api/v1/jobs/').to_return(status: 202, body: '{ "template": "tickets_excel", "status": "RECEIVED", "id": 272, "product_account_id": "1", "output_path": "null" }', headers: {})

    count_before_export = @account.data_exports.count
    args = { format: 'csv' }
    Tickets::Export::TicketsExport.new.perform(args)
    assert_equal count_before_export + 1, @account.data_exports.count
    export_job = @account.data_exports.order('id asc').last
    assert_equal '272', export_job.job_id
  ensure
    @account.rollback(:silkroad_export)
    Tickets::Export::TicketsExport.any_instance.unstub(:send_to_silkroad?)
    Silkroad::Export::Ticket.any_instance.unstub(:generate_headers)
    Silkroad::Export::Ticket.any_instance.unstub(:build_request_body)
  end
end
