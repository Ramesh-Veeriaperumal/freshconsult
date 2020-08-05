require_relative '../test_helper'
require 'webmock/minitest'

class SilkroadBaseTest < ActionView::TestCase
  def setup
    super
    @account = Account.first.make_current
    @account.technicians.first.make_current
  end

  def test_create_data_exports_job_sucess
    Silkroad::Export::Ticket.any_instance.stubs(:generate_headers).returns({})
    Silkroad::Export::Ticket.any_instance.stubs(:build_request_body).returns({})
    stub_request(:post, 'http://localhost:1728/api/v1/jobs/').to_return(status: 202, body: '{ "template": "csv", "status": "RECEIVED", "id": 271, "product_account_id": "1", "output_path": "null" }', headers: {})
    count_before_export = @account.data_exports.count
    export_job = Silkroad::Export::Ticket.new.create_job({})
    assert_equal count_before_export + 1, @account.data_exports.count
    assert_equal '271', export_job.job_id
  ensure
    Silkroad::Export::Ticket.any_instance.unstub(:generate_headers)
    Silkroad::Export::Ticket.any_instance.unstub(:build_request_body)
  end

  def test_create_data_exports_job_failure
    Silkroad::Export::Ticket.any_instance.stubs(:generate_headers).returns({})
    Silkroad::Export::Ticket.any_instance.stubs(:build_request_body).returns({})
    stub_request(:post, 'http://localhost:1728/api/v1/jobs/').to_return(status: 403, body: '{}', headers: {})
    count_before_export = @account.data_exports.count
    export_job = Silkroad::Export::Ticket.new.create_job({})
    assert_equal nil, export_job
    assert_equal count_before_export, @account.data_exports.count
  ensure
    Silkroad::Export::Ticket.any_instance.unstub(:generate_headers)
    Silkroad::Export::Ticket.any_instance.unstub(:build_request_body)
  end

  def test_get_job_status_success
    Silkroad::Export::Ticket.any_instance.stubs(:generate_headers).returns({})
    stub_request(:get, 'http://localhost:1728/api/v1/jobs/271').to_return(status: 200, body: '{ "template": "csv", "status": "COMPLETED", "id": 271, "product_account_id": "1", "output_path": "null" }', headers: {})
    job_status = Silkroad::Export::Ticket.new.get_job_status(271).symbolize_keys
    required_job_status = { template: 'csv', status: 'COMPLETED', id: 271, product_account_id: '1', output_path: 'null' }
    assert_equal required_job_status, job_status
  ensure
    Silkroad::Export::Ticket.any_instance.unstub(:generate_headers)
  end

  def test_get_job_status_failure
    Silkroad::Export::Ticket.any_instance.stubs(:generate_headers).returns({})
    stub_request(:get, 'http://localhost:1728/api/v1/jobs/271').to_return(status: 403, body: '{ "error_message": "Forbidden" }', headers: {})
    job_status = Silkroad::Export::Ticket.new.get_job_status(271).symbolize_keys
    required_job_status = { error_message: 'Forbidden' }
    assert_equal required_job_status, job_status
  ensure
    Silkroad::Export::Ticket.any_instance.unstub(:generate_headers)
  end

  def test_shadow_export_with_silkroad
    Export::Ticket.any_instance.stubs(:export_tickets).returns(nil)
    Export::Ticket.any_instance.stubs(:upload_file).returns(nil)
    Export::Ticket.any_instance.stubs(:send_to_silkroad?).returns(true)
    Export::Ticket.any_instance.stubs(:hash_url).returns(nil)
    Export::Ticket.any_instance.stubs(:schedule_export_cleanup).returns(nil)
    DataExportMailer.stubs(:send_email).returns(nil)
    Silkroad::Export::Ticket.any_instance.stubs(:generate_headers).returns({})
    Silkroad::Export::Ticket.any_instance.stubs(:build_request_body).returns({})
    stub_request(:post, 'http://localhost:1728/api/v1/jobs/').to_return(status: 202, body: '{ "template": "csv", "status": "RECEIVED", "id": 271, "product_account_id": "1", "output_path": "null" }', headers: {})

    count_before_export = @account.data_exports.count
    export_params = { format: 'csv', portal_url: 'portal_url' }
    Export::Ticket.new(export_params).perform

    assert_equal count_before_export + 2, @account.data_exports.count
    data_exports = @account.data_exports.order('id asc').last(2)
    helpkit_export = data_exports.first
    silkroad_export = data_exports.last
    required_export_params = { format: 'csv', portal_url: 'portal_url', export_fields: {}, helpkit_export_id: helpkit_export.id }
    assert_equal required_export_params, silkroad_export.export_params
  ensure
    Export::Ticket.any_instance.unstub(:@export_tickets)
    Export::Ticket.any_instance.unstub(:upload_file)
    Export::Ticket.any_instance.unstub(:send_to_silkroad?)
    Export::Ticket.any_instance.unstub(:hash_url)
    Export::Ticket.any_instance.unstub(:schedule_export_cleanup)
    DataExportMailer.unstub(:send_email)
    Silkroad::Export::Ticket.any_instance.unstub(:generate_headers)
    Silkroad::Export::Ticket.any_instance.unstub(:build_request_body)
  end

  def test_shadow_export_without_silkroad
    Export::Ticket.any_instance.stubs(:export_tickets).returns(nil)
    Export::Ticket.any_instance.stubs(:upload_file).returns(nil)
    Export::Ticket.any_instance.stubs(:send_to_silkroad?).returns(false)
    Export::Ticket.any_instance.stubs(:hash_url).returns(nil)
    Export::Ticket.any_instance.stubs(:schedule_export_cleanup).returns(nil)
    DataExportMailer.stubs(:send_email).returns(nil)

    count_before_export = @account.data_exports.count
    export_params = { format: 'csv', portal_url: 'portal_url' }
    Export::Ticket.new(export_params).perform

    assert_equal count_before_export + 1, @account.data_exports.count
    helpkit_export = @account.data_exports.order('id asc').last
    required_export_params = {}
    assert_equal required_export_params, helpkit_export.export_params
  ensure
    Export::Ticket.any_instance.unstub(:@export_tickets)
    Export::Ticket.any_instance.unstub(:upload_file)
    Export::Ticket.any_instance.unstub(:send_to_silkroad?)
    Export::Ticket.any_instance.unstub(:hash_url)
    Export::Ticket.any_instance.unstub(:schedule_export_cleanup)
    DataExportMailer.unstub(:send_email)
  end

  def test_auth_header_contains_bearer_token
    assert Silkroad::Export::Base.new.construct_jwt_with_bearer(User.current).include?('Bearer ')
  end
end
