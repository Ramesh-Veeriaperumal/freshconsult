require_relative '../test_helper'
class ApiCustomerImportsControllerTest < ActionController::TestCase
  include CustomerImportConstants
  include Redis::RedisKeys
  include Redis::OthersRedis
  include AttachmentsTestHelper

  def setup
    super
    Sidekiq::Worker.clear_all
    before_all
  end

  def before_all
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
  end

  def wrap_cname(params)
    { api_customer_import: params }
  end

  def test_index_with_no_existing_contact_import
    remove_contact_imports_if_exists
    get :index, controller_params({})
    assert_response 200
    match_json([])
  end

  def test_index_with_no_existing_company_import
    remove_company_imports_if_exists
    @request.path = '/api/_/companies/imports'
    get :index, controller_params({})
    assert_response 200
    match_json([])
  end

  def test_index_with_existing_contact_import
    remove_contact_imports_if_exists
    import = @account.contact_imports.create!(IMPORT_STARTED)
    get :index, controller_params({})
    assert_response 200
    response_body = []
    response_body << import_show_result(import).merge(status: 'in_progress',
                                                      failures: {})
    match_json(response_body)
  end

  def test_index_with_existing_company_import
    remove_company_imports_if_exists
    import = @account.company_imports.create!(IMPORT_STARTED)
    @request.path = '/api/_/companies/imports'
    get :index, controller_params({})
    assert_response 200
    response_body = []
    response_body << import_show_result(import).merge(status: 'in_progress',
                                                      failures: {})
    match_json(response_body)
  end

  def test_index_with_existing_contact_import_with_filter
    remove_contact_imports_if_exists
    import = @account.contact_imports.create!(IMPORT_STARTED)
    get :index, controller_params(status: 'in_progress')
    assert_response 200
    response_body = []
    response_body << import_show_result(import).merge(status: 'in_progress',
                                                      failures: {})
    match_json(response_body)
  end

  def test_index_with_existing_company_import_with_filter
    remove_company_imports_if_exists
    import = @account.company_imports.create!(IMPORT_STARTED)
    @request.path = '/api/_/companies/imports'
    get :index, controller_params(status: 'in_progress')
    assert_response 200
    response_body = []
    response_body << import_show_result(import).merge(status: 'in_progress',
                                                      failures: {})
    match_json(response_body)
  end

  def test_import_contacts
    remove_contact_imports_if_exists
    post :create, construct_params(import_contacts_params)
    import = @account.reload.contact_imports.running_contact_imports.first
    assert_response 200
    response_body = import_show_result(import).merge(status: 'in_progress',
                                                     total_records: 2,
                                                     failures: {})
    match_json(response_body)
    assert_equal import.import_status, Admin::DataImport::IMPORT_STATUS[:started]
  end

  def test_import_companies
    remove_company_imports_if_exists
    @request.path = '/api/_/companies/imports'
    post :create, construct_params(import_companies_params)
    import = @account.reload.company_imports.running_company_imports.first
    assert_response 200
    response_body = import_show_result(import).merge(status: 'in_progress',
                                                     total_records: 2,
                                                     failures: {})
    match_json(response_body)
    assert_equal import.import_status, Admin::DataImport::IMPORT_STATUS[:started]
  end

  def test_contact_import_cancel_and_show
    @request.env['CONTENT_TYPE'] = 'application/json'
    import = @account.reload.contact_imports.running_contact_imports.first ||
             @account.contact_imports.create!(IMPORT_STARTED)
    set_keys(import, 'CONTACT')
    put :cancel, controller_params(id: import.id)
    assert_response 200
    match_json(import_show_result(import).merge(status: 'cancelled',
                                                total_records: 2,
                                                completed_records: 2,
                                                failures: { count: 1 }))
  end

  def test_contact_cancelled_import_show
    import = @account.reload.contact_imports.running_contact_imports.first ||
             @account.contact_imports.create!(IMPORT_STARTED)
    set_keys(import, 'CONTACT')
    import.cancelled!
    get :show, controller_params(id: import.id)
    assert_response 200
    response = import_show_result(import).merge(status: 'cancelled',
                                                total_records: 2,
                                                completed_records: 1,
                                                failures: { count: 1 })
    match_json response
  end


  def test_company_import_cancel
    @request.env['CONTENT_TYPE'] = 'application/json'
    import = @account.reload.company_imports.running_contact_imports.first ||
             @account.company_imports.create!(IMPORT_STARTED)
    set_keys(import, 'COMPANY')
    @request.path = '/api/_/companies/import'
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
    set_keys(import, 'COMPANY')
    import.cancelled!
    @request.path = '/api/_/companies/import'

    get :show, controller_params(id: import.id)
    assert_response 200
    response = import_show_result(import).merge(status: 'cancelled',
                                                total_records: 2,
                                                completed_records: 1,
                                                failures: { count: 1 })
    match_json response
  end

  def test_contact_import_cancel_invalid_import
    @request.env['CONTENT_TYPE'] = 'application/json'
    put :cancel, controller_params(id: 9999)
    assert_response 404
  end

  def test_company_import_cancel_invalid_import
    @request.env['CONTENT_TYPE'] = 'application/json'
    @request.path = '/api/_/companies/import'
    put :cancel, controller_params(id: 9999)
    assert_response 404
  end

  def test_contact_import_cancel_completed_import
    @request.env['CONTENT_TYPE'] = 'application/json'
    import = @account.contact_imports.create!(import_status: Admin::DataImport::IMPORT_STATUS[:completed])
    @account.reload
    put :cancel, controller_params(id: import.id)
    assert_response 404
  end

  def test_company_import_cancel_completed_import
    @request.env['CONTENT_TYPE'] = 'application/json'
    @request.path = '/api/_/companies/import'
    import = @account.company_imports.create!(import_status: Admin::DataImport::IMPORT_STATUS[:completed])
    @account.reload
    put :cancel, controller_params(id: import.id)
    assert_response 404
  end

  def test_create_import_for_400_on_invalid_file_format
    remove_contact_imports_if_exists
    request_params = { file: fixture_file_upload('/files/attachment.txt', 'txt'),
                       fields: { name: '1',
                                 email: '0',
                                 job_title: '3' } }
    post :create, construct_params(request_params)
    assert_response 400
  end

  def test_create_company_import_for_400_on_invalid_file_format
    remove_company_imports_if_exists
    request_params = { file: fixture_file_upload('/files/attachment.txt', 'txt'),
                       fields: { name: '1',
                                 email: '0',
                                 job_title: '3' } }
    @request.path = '/api/_/companies/imports'
    post :create, construct_params(request_params)
    assert_response 400
  end

  def test_upload_csv_for_429_on_existing_import_in_progress
    import = @account.reload.contact_imports.running_contact_imports.first ||
             @account.contact_imports.create!(IMPORT_STARTED)
    @account.reload
    post :create, construct_params(import_contacts_params)
    assert_response 429
  end

  def test_upload_csv_for_429_on_existing_company_import_in_progress
    import = @account.reload.contact_imports.running_company_imports.first ||
             @account.company_imports.create!(IMPORT_STARTED)
    @account.reload
    @request.path = '/api/_/companies/imports'
    post :create, construct_params(import_companies_params)
    assert_response 429
  end

  def test_show_with_invalid_import
    get :show, controller_params(id: 9999)
    assert_response 404
  end

  def test_show_with_invalid_company_import
    @request.path = '/api/_/companies/import'
    get :show, controller_params(id: 9999)
    assert_response 404
  end

  def test_import_show_failed
    import = @account.contact_imports.create!(import_status: Admin::DataImport::IMPORT_STATUS[:failed])
    @account.reload
    set_keys(import, 'CONTACT')
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

  def test_company_import_show_failed
    import = @account.company_imports.create!(import_status: Admin::DataImport::IMPORT_STATUS[:failed])
    @account.reload
    set_keys(import, 'COMPANY')
    attachment = create_attachment(attachable_type: 'Admin::DataImport', attachable_id: import.id)
    @request.path = '/api/_/companies/import'
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

  def test_import_show_in_progress
    import = @account.reload.contact_imports.running_contact_imports.first ||
             @account.contact_imports.create!(IMPORT_STARTED)
    @account.reload
    set_keys(import, 'CONTACT')
    get :show, controller_params(id: import.id)
    assert_response 200
    response_body = import_show_result(import).merge(status: 'in_progress',
                                                     total_records: 2,
                                                     completed_records: 1,
                                                     estimated_time_remaining: String,
                                                     failures: { count: 1 })
    match_json response_body
  end

  def test_company_import_show_in_progress
    import = @account.reload.company_imports.running_company_imports.first ||
             @account.company_imports.create!(IMPORT_STARTED)
    @account.reload
    set_keys(import, 'COMPANY')
    @request.path = '/api/_/companies/import'
    get :show, controller_params(id: import.id)
    assert_response 200
    response_body = import_show_result(import).merge(status: 'in_progress',
                                                     total_records: 2,
                                                     completed_records: 1,
                                                     estimated_time_remaining: String,
                                                     failures: { count: 1 })
    match_json response_body
  end

  def remove_contact_imports_if_exists
    if @account.reload.contact_imports
      @account.contact_imports.destroy_all
      @account.reload
    end
  end

  def remove_company_imports_if_exists
    if @account.company_imports
      @account.company_imports.destroy_all
      @account.reload
    end
  end

  def set_keys(import, type)
    key = Object.const_get("#{type}_IMPORT_FAILED_RECORDS") % { account_id: @account.id,
                                                                import_id: import.id }
    set_others_redis_with_expiry(key, 1, {})
    key = Object.const_get("#{type}_IMPORT_FINISHED_RECORDS") % { account_id: @account.id,
                                                                  import_id: import.id }
    set_others_redis_with_expiry(key, 1, {})
    key = Object.const_get("#{type}_IMPORT_TOTAL_RECORDS") % { account_id: @account.id,
                                                               import_id: import.id }
    set_others_redis_with_expiry(key, 2, {})
    Helpdesk::Attachment.any_instance.stubs(:attachment_url_for_api).returns('spec/fixtures/files/attachment.csv')
  end

  def import_contacts_params
    { file: fixture_file_upload('files/contacts_import.csv', 'text/csv', :binary),
      fields: { name: '1',
                email: '0',
                job_title: '3' } }
  end

  def import_companies_params
    { file: fixture_file_upload('files/companies_import.csv', 'text/csv', :binary),
      fields: { name: '0',
                note: '2' } }
  end

  def import_show_result(import)
    {
      id: import.id,
      created_at: import.created_at.try(:utc).iso8601
    }
  end
end
