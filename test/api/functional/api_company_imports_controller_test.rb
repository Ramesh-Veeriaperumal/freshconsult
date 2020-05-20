require_relative '../test_helper'
class ApiCompanyImportsControllerTest < ActionController::TestCase
  include CustomerImportConstants
  include Redis::RedisKeys
  include Redis::OthersRedis
  include AttachmentsTestHelper
  include ImportTestHelper

  IMPORT_FIELD_PARAMS = { name: '0', note: '2' }.freeze

  def setup
    super
    Sidekiq::Worker.clear_all
    before_all
    remove_imports_if_exists('company')
  end

  def before_all
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
  end

  def wrap_cname(params)
    { api_customer_import: params }
  end

  def test_index_with_no_existing_company_import
    get :index, controller_params({})
    assert_response 200
    match_json([])
  end

  def test_index_with_existing_company_import
    import = @account.company_imports.create!(IMPORT_STARTED)
    get :index, controller_params({})
    assert_response 200
    response_body = []
    response_body << import_show_result(import).merge(status: 'in_progress',
                                                      failures: {})
    match_json(response_body)
  end

  def test_index_with_existing_company_import_with_filter
    import = @account.company_imports.create!(IMPORT_STARTED)
    get :index, controller_params(status: 'in_progress')
    assert_response 200
    response_body = []
    response_body << import_show_result(import).merge(status: 'in_progress',
                                                      failures: {})
    match_json(response_body)
  end

  def test_import_companies
    post :create, construct_params(import_params('company', IMPORT_FIELD_PARAMS))
    import = @account.reload.company_imports.running_company_imports.first
    assert_response 200
    response_body = import_show_result(import).merge(status: 'in_progress',
                                                     total_records: 2,
                                                     failures: {})
    match_json(response_body)
    assert_equal import.import_status, Admin::DataImport::IMPORT_STATUS[:started]
  end

  def test_company_import_cancel
    @request.env['CONTENT_TYPE'] = 'application/json'
    import = @account.reload.company_imports.running_contact_imports.first ||
             @account.company_imports.create!(IMPORT_STARTED)
    set_keys(@account, import, 'COMPANY')
    put :cancel, controller_params(id: import.id)
    assert_response 200
    match_json(import_show_result(import).merge(status: 'cancelled',
                                                total_records: 2,
                                                completed_records: 2,
                                                failures: { count: 1 }))
  end

  def test_company_cancelled_import_show
    import = @account.reload.company_imports.running_contact_imports.first ||
             @account.company_imports.create!(IMPORT_STARTED)
    set_keys(@account, import, 'COMPANY')
    import.cancelled!

    get :show, controller_params(id: import.id)
    assert_response 200
    response = import_show_result(import).merge(status: 'cancelled',
                                                total_records: 2,
                                                completed_records: 1,
                                                failures: { count: 1 })
    match_json response
  end

  def test_company_import_cancel_invalid_import
    @request.env['CONTENT_TYPE'] = 'application/json'
    put :cancel, controller_params(id: 9999)
    assert_response 404
  end

  def test_company_import_cancel_completed_import
    @request.env['CONTENT_TYPE'] = 'application/json'
    import = @account.company_imports.create!(import_status: Admin::DataImport::IMPORT_STATUS[:completed])
    @account.reload
    put :cancel, controller_params(id: import.id)
    assert_response 404
  end

  def test_create_company_import_for_400_on_invalid_file_format
    request_params = { file: fixture_file_upload('/files/attachment.txt', 'txt'),
                       fields: { name: '1',
                                 email: '0',
                                 job_title: '3' } }
    post :create, construct_params(request_params)
    assert_response 400
  end

  def test_upload_csv_for_429_on_existing_company_import_in_progress
    import = @account.reload.contact_imports.running_company_imports.first ||
             @account.company_imports.create!(IMPORT_STARTED)
    @account.reload
    post :create, construct_params(import_params('company', IMPORT_FIELD_PARAMS))
    assert_response 429
  end

  def test_show_with_invalid_company_import
    get :show, controller_params(id: 9999)
    assert_response 404
  end

  def test_company_import_show_failed
    import = @account.company_imports.create!(import_status: Admin::DataImport::IMPORT_STATUS[:failed])
    @account.reload
    set_keys(@account, import, 'COMPANY')
    attachment = create_attachment(attachable_type: 'Admin::DataImport', attachable_id: import.id)
    get :show, controller_params(id: import.id)
    assert_response 200
    response = import_show_result(import).merge(status: 'failed',
                                                total_records: 2,
                                                completed_records: 1,
                                                failures: { count: 1,
                                                            report: 'spec/fixtures/files/attachment.csv' })
    match_json response
    Helpdesk::Attachment.any_instance.unstub(:attachment_url_for_api)
  end

  def test_company_import_show_in_progress
    import = @account.reload.company_imports.running_company_imports.first ||
             @account.company_imports.create!(IMPORT_STARTED)
    @account.reload
    set_keys(@account, import, 'COMPANY')
    get :show, controller_params(id: import.id)
    assert_response 200
    response_body = import_show_result(import).merge(status: 'in_progress',
                                                     total_records: 2,
                                                     completed_records: 1,
                                                     estimated_time_remaining: String,
                                                     failures: { count: 1 })
    match_json response_body
  end

  def test_company_import_200_on_uppercase_csv_file_format
    request_params = { file: fixture_file_upload('/files/companies2_import.CSV', 'text/csv', :binary),
                       fields: { name: '0',
                                 description: '1',
                                 note: '2' } }
    post :create, construct_params(request_params)
    assert_response 200
  end
end
