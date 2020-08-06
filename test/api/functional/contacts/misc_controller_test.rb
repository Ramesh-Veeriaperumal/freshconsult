require_relative '../../test_helper'
['solutions_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class Contacts::MiscControllerTest < ActionController::TestCase
  include UsersTestHelper
  include CustomFieldsTestHelper
  include SolutionsHelper
  include EmailConfigsTestHelper
  include AttachmentsTestHelper
  
  BULK_CONTACT_CREATE_COUNT = 2
  def setup
    super
    initial_setup
  end

  @@initial_setup_run = false

  def initial_setup
    return if @@initial_setup_run
    @account.add_feature(:falcon)
    @account.reload
    @@initial_setup_run = true
  end

  def create_n_users(count, account, params = {})
    contact_ids = []
    count.times do
      contact_ids << add_new_user(account, params).id
    end
    contact_ids
  end

  def test_send_invite
    contact = add_new_user(@account, active: false)
    put :send_invite, controller_params(id: contact.id)
    assert_response 204
  end


  def test_send_invite_main_portal
    contact = add_new_user(@account, active: false)
    put :send_invite, controller_params(id: contact.id)
    assert_equal Portal.current.main_portal, true
    assert_response 204
  end

  def test_send_invite_portal
    contact = add_new_user(@account, active: false)
    pdt = Product.new(name: 'Product A')
    pdt.save
    create_email_config(product_id: pdt.id)
    portal_custom = create_portal(portal_url: 'sample.freshpo.com' , product_id: pdt.id)
    @request.host = portal_custom.portal_url
    put :send_invite, controller_params(id: contact.id)
    assert_equal Portal.current, portal_custom
    assert_response 204
  end


  def test_send_invite_to_active_contact
    contact = add_new_user(@account, active: true)
    put :send_invite, controller_params(id: contact.id)
    match_json([bad_request_error_pattern('id', :invalid_user_for_activation, reason: 'active')])
    assert_response 400
  end

  def test_send_invite_to_deleted_contact
    contact = add_new_user(@account, deleted: true, active: false)
    put :send_invite, controller_params(id: contact.id)
    match_json([bad_request_error_pattern('id', :invalid_user_for_activation, reason: 'deleted')])
    assert_response 400
  end

  def test_send_invite_to_merged_contact
    contact = add_new_user(@account, deleted: true)
    contact.parent_id = 999
    contact.save
    put :send_invite, controller_params(id: contact.id)
    match_json([bad_request_error_pattern('id', :invalid_user_for_activation, reason: 'merged')])
    assert_response 400
    contact.parent_id = nil
  end

  def test_send_invite_to_blocked_contact
    contact = add_new_user(@account, blocked: true)
    put :send_invite, controller_params(id: contact.id)
    match_json([bad_request_error_pattern('id', :invalid_user_for_activation, reason: 'blocked')])
    assert_response 400
  end

  def test_export_csv_with_no_params
    create_n_users(BULK_CONTACT_CREATE_COUNT, @account)
    contact_form = @account.contact_form
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:contact], account_id: @account.id)
    params_hash = { fields: {} }
    post :export, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(:fields, :blank)])
  end

  def test_export_csv_with_invalid_params
    create_n_users(BULK_CONTACT_CREATE_COUNT, @account)
    contact_form = @account.contact_form
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:contact], account_id: @account.id)
    params_hash = { fields: { default_fields: [Faker::Lorem.word], custom_fields: [Faker::Lorem.word] } }
    post :export, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(:default_fields, :not_included, list: contact_form.safe_send(:default_contact_fields, true).map(&:name).join(',')),
                bad_request_error_pattern(:custom_fields, :not_included, list: (contact_form.safe_send(:custom_contact_fields).map(&:name).collect { |x| x[3..-1] }).uniq.join(','))])
  end

  def test_response_for_export_csv_with_invalid_params
    create_n_users(BULK_CONTACT_CREATE_COUNT, @account)
    contact_form = @account.contact_form
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:contact], account_id: @account.id)
    params_hash = { fields: { default_fields: [Faker::Lorem.word], custom_fields: [Faker::Lorem.word] } }
    post :export, construct_params(params_hash)
    assert_response 400
    assert_include response.body, 'time_zone'
    assert_include response.body, 'language'
  end

  def test_export_csv_with_invalid_field_params
    create_n_users(BULK_CONTACT_CREATE_COUNT, @account)
    contact_form = @account.contact_form
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:contact], account_id: @account.id)
    params_hash = { invalid_fields: {} }
    post :export, construct_params(params_hash)
    assert_response 400
  end

  def test_export_csv
    create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'Area', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Metropolitian City', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'date', field_type: 'custom_date', label: 'Joining date', editable_in_signup: 'true'))
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:contact], account_id: @account.id)
    create_n_users(BULK_CONTACT_CREATE_COUNT, @account)
    default_fields = @account.contact_form.default_contact_fields
    custom_fields = @account.contact_form.custom_contact_fields
    Export::ContactWorker.jobs.clear
    params_hash = { fields: { default_fields: default_fields.map(&:name), custom_fields: custom_fields.map(&:name).collect { |x| x[3..-1] } } }
    post :export, construct_params(params_hash)
    assert_response 200
    sidekiq_jobs = Export::ContactWorker.jobs
    assert_equal 1, sidekiq_jobs.size
    csv_hash = (default_fields | custom_fields).collect { |x| { x.label => x.name } }.inject(&:merge)
    assert_equal csv_hash, sidekiq_jobs.first['args'][0]['csv_hash']
    assert_equal User.current.id, sidekiq_jobs.first['args'][0]['user']
    Export::ContactWorker.jobs.clear
  end

  def test_export_csv_with_limit_reach
    create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'Area', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Metropolitian City', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'date', field_type: 'custom_date', label: 'Joining date', editable_in_signup: 'true'))
    create_n_users(BULK_CONTACT_CREATE_COUNT, @account)
    default_fields = @account.contact_form.default_contact_fields
    custom_fields = @account.contact_form.custom_contact_fields
    DataExport.contact_export_limit.times do
      export_entry = @account.data_exports.new(source: DataExport::EXPORT_TYPE['contact'.to_sym],
                                               user: User.current,
                                               status: DataExport::EXPORT_STATUS[:started])
      export_entry.save
    end
    params_hash = { fields: { default_fields: default_fields.map(&:name), custom_fields: custom_fields.map(&:name).collect { |x| x[3..-1] } } }
    post :export, construct_params(params_hash)
    assert_response 429
  end

  def test_export_csv_details_completed
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:contact], account_id: @account.id)
    export_entry = @account.data_exports.new(source: DataExport::EXPORT_TYPE['contact'.to_sym],
                                             user: User.current,
                                             status: DataExport::EXPORT_STATUS[:completed],
                                             token: Faker::Number.number(10))
    export_entry.save
    attachment = create_attachment(attachable_type: 'DataExport', attachable_id: export_entry.id)
    AwsWrapper::S3.stubs(:presigned_url).returns('spec/fixtures/files/attachment.csv')
    get :export_details, construct_params(id: export_entry.token)
    assert_response 200
    response_hash = { id: export_entry.token,
                      status: 'completed',
                      download_url: 'spec/fixtures/files/attachment.csv' }
    match_json(response_hash)
    AwsWrapper::S3.unstub(:presigned_url)
  end

  def test_export_csv_details_with_invalid_token
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:contact], account_id: @account.id)
    export_entry = @account.data_exports.new(source: DataExport::EXPORT_TYPE['contact'.to_sym],
                                             user: User.current,
                                             status: DataExport::EXPORT_STATUS[:started],
                                             token: Faker::Number.number(10))
    export_entry.save
    get :export_details, construct_params(id: 'abc')
    assert_response 404
  end

  def test_export_csv_details_with_invalid_source
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:contact], account_id: @account.id)
    export_entry = @account.data_exports.new(source: DataExport::EXPORT_TYPE['company'.to_sym],
                                             user: User.current,
                                             status: DataExport::EXPORT_STATUS[:started],
                                             token: Faker::Number.number(10))
    export_entry.save
    get :export_details, construct_params(id: export_entry.token)
    assert_response 404
  end

  def test_export_csv_details_in_progress
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:contact], account_id: @account.id)
    export_entry = @account.data_exports.new(source: DataExport::EXPORT_TYPE['contact'.to_sym],
                                             user: User.current,
                                             status: DataExport::EXPORT_STATUS[:started],
                                             token: Faker::Number.number(10))
    export_entry.save
    get :export_details, construct_params(id: export_entry.token)
    assert_response 200
    response_hash = { id: export_entry.token,
                      status: 'in_progress' }
    match_json(response_hash)
  end

  def test_export_csv_without_privilege
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:contact], account_id: @account.id)
    User.any_instance.stubs(:privilege?).with(:export_customers).returns(false)
    create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'Area', editable_in_signup: 'true'))
    default_fields = @account.contact_form.default_contact_fields
    custom_fields = @account.contact_form.custom_contact_fields
    params_hash = { fields: { default_fields: default_fields.map(&:name), custom_fields: custom_fields.map(&:name).collect { |x| x[3..-1] } } }
    post :export, construct_params(params_hash)
    assert_response 403
    User.any_instance.unstub(:privilege?)
  end

  def test_export_details_without_privilege
    User.any_instance.stubs(:privilege?).with(:export_customers).returns(false)
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:contact], account_id: @account.id)
    export_entry = @account.data_exports.new(source: DataExport::EXPORT_TYPE['contact'.to_sym],
                                             user: User.current,
                                             status: DataExport::EXPORT_STATUS[:started],
                                             token: Faker::Number.number(10))
    export_entry.save
    params_hash = { id: export_entry.token }
    post :export_details, construct_params(params_hash)
    assert_response 403
    User.any_instance.unstub(:privilege?)
  end
end
