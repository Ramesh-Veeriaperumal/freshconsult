require_relative '../../../test_helper'
class Channel::Admin::DataExportControllerTest < ActionController::TestCase
  include Silkroad::Constants::Ticket

  def wrap_cname(params)
    params
  end

  def create_dataexport(type, job_id, status = DataExport::EXPORT_STATUS[:started])
    @account = Account.first.make_current
    @user = @account.technicians.first
    @data_export = @account.data_exports.new(source: DataExport::EXPORT_TYPE[type.to_sym],
                                             user: @user,
                                             status: status,
                                             job_id: job_id,
                                             export_params: { 'format' => 'csv', 'date_filter' => '30', 'ticket_state_filter' => 'created_at', 'query_hash' => [{ 'condition' => 'created_at', 'operator' => 'is_greater_than', 'value' => 'last_month' }], 'start_date' => '2020-02-09 00:00:00', 'end_date' => '2020-03-10 23:59:59', 'ticket_fields' => { 'display_id' => 'Ticket ID', 'subject' => 'Subject', 'status_name' => 'Status' }, 'contact_fields' => { 'name' => 'Full name', 'contact_id' => 'Contact ID' }, 'company_fields' => {}, 'filter_name' => 'all_tickets', 'export_fields' => { 'display_id' => 'Ticket ID', 'subject' => 'Subject', 'status_name' => 'Status' }, 'current_user_id' => 1, 'portal_url' => 'localhost.freshdesk-dev.com', 'data_hash' => [{ 'condition' => 'created_at', 'operator' => 'is_greater_than', 'value' => 'last_month' }, { 'condition' => 'spam', 'operator' => 'is', 'value' => false }, { 'condition' => 'deleted', 'operator' => 'is', 'value' => false }] })
    @data_export.save
    @data_export.export_params = { 'format' => 'csv', helpkit_export_id: @data_export.id, 'date_filter' => '30', 'ticket_state_filter' => 'created_at', 'query_hash' => [{ 'condition' => 'created_at', 'operator' => 'is_greater_than', 'value' => 'last_month' }], 'start_date' => '2020-02-09 00:00:00', 'end_date' => '2020-03-10 23:59:59', 'ticket_fields' => { 'display_id' => 'Ticket ID', 'subject' => 'Subject', 'status_name' => 'Status' }, 'contact_fields' => { 'name' => 'Full name', 'contact_id' => 'Contact ID' }, 'company_fields' => {}, 'filter_name' => 'all_tickets', 'export_fields' => { 'display_id' => 'Ticket ID', 'subject' => 'Subject', 'status_name' => 'Status' }, 'current_user_id' => 1, 'portal_url' => 'localhost.freshdesk-dev.com', 'data_hash' => [{ 'condition' => 'created_at', 'operator' => 'is_greater_than', 'value' => 'last_month' }, { 'condition' => 'spam', 'operator' => 'is', 'value' => false }, { 'condition' => 'deleted', 'operator' => 'is', 'value' => false }] }
    @data_export.save
    @data_export
  end

  def test_update_silkroad_without_jwt_header
    job_id = rand(300..99_999)
    export = create_dataexport(:ticket, job_id)
    post :update, construct_params({ version: 'channel' }, job_id: job_id, status: 2, column_name: 'ticket_created', start_date: '2019-12-01 00:00:00', end_date: '2019-12-01 00:00:00')
    assert_response 403
  end

  def test_update_silkroad_status_not_in_started
    job_id = rand(300..99_999)
    count_of_delayed_jobs_before = Delayed::Job.count
    export = create_dataexport(:ticket, job_id, DataExport::EXPORT_STATUS[:file_created])
    set_jwt_auth_header('silkroad')
    post :update, construct_params({ version: 'channel' }, job_id: job_id, status: 3, column_name: 'ticket_created', start_date: '2019-12-01 00:00:00', end_date: '2019-12-01 00:00:00')
    assert_response 200
    export_record = Account.first.data_exports.where(job_id: job_id).last
    assert_equal export_record.status, 2
    assert_equal count_of_delayed_jobs_before, Delayed::Job.count
  end

  def test_update_silkroad_status_3
    job_id = rand(300..99_999)
    count_of_delayed_jobs_before = Delayed::Job.count
    export = create_dataexport(:ticket, job_id)
    set_jwt_auth_header('silkroad')
    post :update, construct_params({ version: 'channel' }, job_id: job_id, status: 3, column_name: 'ticket_created', start_date: '2019-12-01 00:00:00', end_date: '2019-12-01 00:00:00')
    assert_response 200
    export_record = Account.first.data_exports.where(job_id: job_id).last
    assert_equal export_record.status, 4
    assert_equal count_of_delayed_jobs_before, Delayed::Job.count
  end

  def test_update_silkroad_status_3_with_silkroad_export_launched
    @account.launch(:silkroad_export)
    job_id = rand(300..99_999)
    count_of_delayed_jobs_before = Delayed::Job.count
    export = create_dataexport(:ticket, job_id)
    set_jwt_auth_header('silkroad')
    post :update, construct_params({ version: 'channel' }, job_id: job_id, status: 3, column_name: 'ticket_created', start_date: '2019-12-01 00:00:00', end_date: '2019-12-01 00:00:00')
    assert_response 200
    export_record = Account.first.data_exports.where(job_id: job_id).last
    assert_equal export_record.status, 4
    assert_equal count_of_delayed_jobs_before+1, Delayed::Job.count
  ensure
    @account.rollback(:silkroad_export)
  end

  def test_update_silkroad_status_4
    @account.launch(:silkroad_export)
    job_id = rand(300..99_999)
    count_of_delayed_jobs_before = Delayed::Job.count
    export = create_dataexport(:ticket, job_id)
    set_jwt_auth_header('silkroad')
    post :update, construct_params({ version: 'channel' }, job_id: job_id, status: 4, column_name: 'ticket_created', start_date: '2019-12-01 00:00:00', end_date: '2019-12-01 00:00:00')
    assert_response 200
    export_record = Account.first.data_exports.where(job_id: job_id).last
    assert_equal export_record.status, 5
    assert_equal count_of_delayed_jobs_before+1, Delayed::Job.count
  ensure
    @account.rollback(:silkroad_export)
  end

  def test_update_silkroad_validation_error_invalid_job_status
    job_id = rand(300..99_999)
    export = create_dataexport(:ticket, job_id)
    set_jwt_auth_header('silkroad')
    post :update, construct_params({ version: 'channel' }, job_id: job_id, status: 1, column_name: 'ticket_created', start_date: '2019-12-01 00:00:00', end_date: '2019-12-01 00:00:00')
    assert_response 400
  end

  def test_update_silkroad_validation_error_invalid_job_id
    set_jwt_auth_header('silkroad')
    post :update, construct_params({ version: 'channel' }, job_id: 'abc', status: 2, column_name: 'ticket_created', start_date: '2019-12-01 00:00:00', end_date: '2019-12-01 00:00:00')
    assert_response 400
  end
end
