require_relative '../test_helper'
require Rails.root.join('test', 'models', 'helpers', 'solutions_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'solutions_articles_test_helper.rb')

class AuditLogsControllerTest < ActionController::TestCase
  include UsersTestHelper
  include AttachmentsTestHelper
  include TestCaseMethods
  include AuditLogSolutionsTestHelper
  include ModelsSolutionsTestHelper
  include SolutionsArticlesTestHelper

  def setup
    super
    initial_setup
    @account.add_feature :audit_logs_central_publish
  end

  def teardown
    @account.revoke_feature :audit_logs_central_publish
  end

  @@initial_setup_run = false

  def initial_setup
    @account = Account.first.present? ? Account.first.make_current : create_test_account
    @@initial_setup_run = true
  end

  def test_audit_log_for_subscription_agent
    HyperTrail::AuditLog.any_instance.stubs(:fetch).returns(hypertrail_sample_response)
    post :filter, version: 'private', format: 'json'
    assert_response 200
    match_json audit_log_filter_response
    assert_equal response.api_meta[:next], next_url
    HyperTrail::AuditLog.any_instance.unstub(:fetch)
  end

  def test_audit_log_event_name
    get :event_name, version: 'private', format: 'json', type: 'dispatcher'
    assert_response 200
    resp = @account.all_va_rules.map { |rule| { name: rule.name, id: rule.id } }
    match_json resp
  end

  def test_audit_log_for_solution_category
    HyperTrail::AuditLog.any_instance.stubs(:fetch).returns(solution_category_sample_data)
    post :filter, version: 'private', format: 'json'
    assert_response 200
    match_json solution_category_filter_response
    assert_equal response.api_meta[:next], solution_category_next_url
  ensure
    HyperTrail::AuditLog.any_instance.unstub(:fetch)
  end

  def test_audit_log_for_solution_folder
    HyperTrail::AuditLog.any_instance.stubs(:fetch).returns(solution_folder_sample_data)
    post :filter, version: 'private', format: 'json'
    assert_response 200
    match_json solution_folder_filter_response
    assert_equal response.api_meta[:next], solution_folder_next_url
  ensure
    HyperTrail::AuditLog.any_instance.unstub(:fetch)
  end

  def test_audit_log_for_solution_article
    HyperTrail::AuditLog.any_instance.stubs(:fetch).returns(solution_article_sample_data)
    post :filter, version: 'private', format: 'json'
    assert_response 200
    match_json solution_article_filter_response
    assert_equal response.api_meta[:next], solution_article_next_url
  ensure
    HyperTrail::AuditLog.any_instance.unstub(:fetch)
  end

  def test_audit_log_for_solution_article_reset_ratings
    setup_redis_for_articles
    article = add_new_article
    HyperTrail::AuditLog.any_instance.stubs(:fetch).returns(solution_article_reset_ratings_data(id: article.parent_id, article_id: article.id))
    post :filter, version: 'private', format: 'json'
    assert_response 200
    match_json solution_article_reset_ratings_response(id: article.parent_id, article_id: article.id)
    assert_equal response.api_meta[:next], solution_article_next_url
  ensure
    HyperTrail::AuditLog.any_instance.unstub(:fetch)
  end

  def test_audit_log_for_solution_article_approval_events
    HyperTrail::AuditLog.any_instance.stubs(:fetch).returns(solution_article_apporval_data)
    post :filter, version: 'private', format: 'json'
    assert_response 200
    match_json solution_article_approval_response
    assert_equal response.api_meta[:next], solution_article_next_url
  ensure
    HyperTrail::AuditLog.any_instance.unstub(:fetch)
  end

  def test_audit_log_filtered_export
    HyperTrail::AuditLog.any_instance.stubs(:trigger_export).returns(filtered_job_id)
    HyperTrail::AuditLog.any_instance.stubs(:retrive_export_data).returns('ce4550a7f2debda6efb7476e')
    post :export, construct_params(audit_log_filtered_params)
    puts("test_audit_log_filtered_export: #{@response.body}")
    assert_response 200
    resp = { status: 'generating export' }
    match_json resp
  end

  def test_audit_log_filtered_export_single_entity
    HyperTrail::AuditLog.any_instance.stubs(:trigger_export).returns(filtered_job_id)
    HyperTrail::AuditLog.any_instance.stubs(:retrive_export_data).returns('ce4550a7f2debda6efb7476e')
    post :export, construct_params(audit_log_filtered_params_single_entity)
    assert_response 200
    puts("test_audit_log_filtered_export_single_entity: #{@response.body}")
    resp = { status: 'generating export' }
    match_json resp
  end

  def test_audit_log_archived_export
    HyperTrail::AuditLog.any_instance.stubs(:trigger_export).returns(archived_job_id)
    HyperTrail::AuditLog.any_instance.stubs(:retrive_export_data).returns('ce4550a7f2debda6efb7476e')
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:audit_log], account_id: @account.id)
    @data_export = @account.data_exports.new(source: DataExport::EXPORT_TYPE['audit_log'.to_sym],
                                             user: User.current,
                                             status: DataExport::EXPORT_STATUS[:completed],
                                             token: archived_job_id['job_id'])
    post :export, construct_params(audit_log_archived_params)
    resp = { status: 'generating export' }
    match_json resp
    assert_response 200
  end

  def test_audit_log_api_export
    HyperTrail::AuditLog.any_instance.stubs(:trigger_export).returns(api_export_response_job_id)
    HyperTrail::AuditLog.any_instance.stubs(:retrive_export_data).returns('ce4550a7f2debda6efb7476e')
    post :export, construct_params(audit_log_api_export_params)
    @response.body.include? api_export_response_job_id['job_id']
    assert_response 200
  end

  def test_audit_log_export_api_response_with_valid_token
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:audit_log], account_id: @account.id)
    @data_export = @account.data_exports.new(source: DataExport::EXPORT_TYPE['audit_log'.to_sym],
                                             user: User.current,
                                             status: DataExport::EXPORT_STATUS[:completed],
                                             token: '0795f174-0bdc-466f-b78e-bc6613a39742')
    @data_export.save
    attachment = @account.attachments.new(content_file_name: 'audit_log/1.zip', content_content_type: 'application/octet-stream',
                                          content_file_size: 40_994, attachable_id: @data_export.id, attachable_type: 'DataExport')
    attachment.save
    AwsWrapper::S3.stubs(:presigned_url).returns(export_api_response_url)
    get :export_s3_url, construct_params(id: '0795f174-0bdc-466f-b78e-bc6613a39742')
    assert_response 200
    resp = { url: export_api_response_url }
    match_json resp
  end

  def test_audit_log_export_api_response_with_failed_status
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:audit_log], account_id: @account.id)
    @data_export = @account.data_exports.new(source: DataExport::EXPORT_TYPE['audit_log'.to_sym],
                                             user: User.current,
                                             status: DataExport::EXPORT_STATUS[:failed],
                                             token: '2affda4a520d08440b81636db30790b89dc626d8')
    @data_export.save
    get :export_s3_url, construct_params(id: '2affda4a520d08440b81636db30790b89dc626d8')
    assert_response 200
    resp = { export_status: 'failed' }
    match_json resp
  end

  def test_audit_log_export_api_response_with_invalid_token
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:audit_log], account_id: @account.id)
    export_entry = @account.data_exports.new(source: DataExport::EXPORT_TYPE['audit_log'.to_sym],
                                             user: User.current,
                                             status: DataExport::EXPORT_STATUS[:completed],
                                             token: '39a26281-4a66-4842-af5b-337fa2741c60')
    export_entry.save
    get :export_s3_url, construct_params(id: '000')
    assert_response 404
  end

  def test_audit_log_export_api_response_with_invalid_export_type
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:audit_log], account_id: @account.id)
    export_entry = @account.data_exports.new(source: DataExport::EXPORT_TYPE['ticket'.to_sym],
                                             user: User.current,
                                             status: DataExport::EXPORT_STATUS[:completed],
                                             token: '39a26281-4a66-4842-af5b-337fa2741c60')
    export_entry.save
    get :export_s3_url, construct_params(id: '39a26281-4a66-4842-af5b-337fa2741c60')
    assert_response 404
  end

  def test_audit_log_api_export_without_privilege
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:audit_log], account_id: @account.id)
    export_entry = @account.data_exports.new(
      source: DataExport::EXPORT_TYPE['audit_log'.to_sym],
      user: User.current,
      status: DataExport::EXPORT_STATUS[:started],
      token: '39a26281-4a66-4842-af5b-337fa2741c60'
    )
    export_entry.save
    post :export_s3_url, construct_params(id: '39a26281-4a66-4842-af5b-337fa2741c60')
    assert_response 403
    User.any_instance.unstub(:privilege?)
  end

  def test_response_job_id
    HyperTrail::AuditLog.any_instance.stubs(:trigger_export).returns(data: [])
    post :export, construct_params(audit_log_export_failed_params)
    assert_response 400
  end

  def test_audit_log_export_dispatcher
    post :export, construct_params(audit_log_delegator_params_dispatcher)
    assert_response 400
  end

  def test_audit_log_export_observer
    post :export, construct_params(audit_log_delegator_params_observer)
    assert_response 400
  end

  def test_audit_log_export_supervisor
    post :export, construct_params(audit_log_delegator_params_supervisor)
    assert_response 400
  end

  def test_audit_log_export_agent
    post :export, construct_params(audit_log_delegator_params_agent)
    assert_response 400
  end

  def test_audit_log_export_actor
    post :export, construct_params(audit_log_delegator_params_actor)
    assert_response 400
  end

  def audit_log_filtered_params
    { version: 'private', format: 'json', from: (Date.today - 1).to_s, to: (Date.today - 4).to_s,
      condition: 'filter_set_1 or action or filter_set_3 or filter_set_2',
      receive_via: 'email',
      export_format: 'csv',
      filter: {
        filter_set_1: {
          entity: ['agent'],
          ids: [1]
        },
        filter_set_2: {
          entity: ['automation_4'],
          ids: [8]
        },
        filter_set_3: {
          entity: ['subscription', 'automation_1']
        },
        action: ['update', 'delete']
      } }
  end

  def audit_log_filtered_params_single_entity
    { version: 'private', format: 'json', from: (Date.today - 1).to_s, to: (Date.today - 4).to_s,
      condition: 'filter_set_1 or action or filter_set_3 or filter_set_2',
      receive_via: 'email',
      export_format: 'xls',
      filter: {
        filter_set_1: {
          entity: ['agent'],
          ids: [1]
        },
        filter_set_2: {
          entity: ['automation_4'],
          ids: [8]
        },
        filter_set_3: {
          entity: ['subscription']
        },
        action: ['update', 'delete']
      } }
  end

  def audit_log_delegator_params_dispatcher
    { version: 'private', format: 'json', from: '2018-09-06', to: '2018-10-30',
      condition: 'filter_set_1 or action',
      receive_via: 'email',
      export_format: 'csv',
      filter: {
        filter_set_1: {
          entity: ['automation_1'],
          ids: ['5001']
        },
        action: ['update', 'delete']
      } }
  end

  def audit_log_delegator_params_observer
    { version: 'private', format: 'json', from: '2018-09-06', to: '2018-10-30',
      condition: 'filter_set_1 or action',
      receive_via: 'email',
      export_format: 'xls',
      filter: {
        filter_set_1: {
          entity: ['automation_4'],
          ids: ['5001']
        },
        action: ['update', 'delete']
      } }
  end

  def audit_log_delegator_params_supervisor
    { version: 'private', format: 'json', from: '2018-09-06', to: '2018-10-30',
      condition: 'filter_set_1 or action',
      receive_via: 'email',
      export_format: 'csv',
      filter: {
        filter_set_1: {
          entity: ['automation_3'],
          ids: ['-2']
        },
        action: ['update', 'delete']
      } }
  end

  def audit_log_delegator_params_agent
    { version: 'private', format: 'json', from: '2018-09-06', to: '2018-10-30',
      condition: 'filter_set_1 or action',
      receive_via: 'email',
      export_format: 'csv',
      filter: {
        filter_set_1: {
          entity: ['agent'],
          ids: ['5001']
        },
        action: ['update', 'delete']
      } }
  end

  def audit_log_delegator_params_actor
    { version: 'private', format: 'json', from: '2018-09-06', to: '2018-10-30',
      receive_via: 'email',
      export_format: 'xls',
      condition: 'performed_by or action',
      filter: {
        action: ['update', 'delete'],
        performed_by: ['100001']
      } }
  end

  def export_api_response_url
    'https://s3.amazonaws.com/cdn.freshpo.com/data/helpdesk/attachments/development/350/original/audit_log/1.zip?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAILZZJD6Q3WAFMCHA%2F20190325%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20190325T101618Z&X-Amz-Expires=300&X-Amz-Signature=a55b8efb502932da1984df0287dce8ef64765e654a99af3072670cfebe135a77&X-Amz-SignedHeaders=Host&response-content-disposition=attachment&response-content-type=application%2Foctet-stream'
  end

  def audit_log_filter_response
    [{ 'time' => 1_526_981_491_586, 'ip_address' => '127. 0. 0. 1', 'name' => { 'name' => '2314211', 'url_type' => 'agent', 'id' => 74_341 }, 'event_performer' => { 'id' => 37, 'name' => 'Admin', 'url_type' => 'agent' }, 'action' => 'update', 'event_type' => 'Agent', 'description' => [{ 'type' => 'default', 'field' => 'Email', 'value' => { 'from' => 'dslads@dsadasa.com', 'to' => 'dsqslads@dsadasa.com' } }, { 'type' => 'default', 'field' => 'Ticket Permission', 'value' => { 'from' => 'Global Access', 'to' => 'Group Access' } }] }, { 'time' => 1_526_980_693_092, 'ip_address' => nil, 'name' => { 'name' => 'subscription', 'url_type' => 'subscription', 'id' => 6 }, 'event_performer' => { 'id' => 0, 'name' => 'system', 'url_type' => 'agent' }, 'action' => 'update', 'event_type' => 'Subscription', 'description' => [{ 'type' => 'default', 'field' => 'Agent Limit', 'value' => { 'from' => 10, 'to' => 9 } }, { 'type' => 'default', 'field' => 'Subscription State', 'value' => { 'from' => 'active', 'to' => 'trial' } }, { 'type' => 'default', 'field' => 'Renewal Period', 'value' => { 'from' => 'Monthly', 'to' => 'Quarterly' } }, { 'type' => 'default', 'field' => 'Card Number', 'value' => { 'from' => '************1111', 'to' => 'dsadadasa' } }, { 'type' => 'default', 'field' => 'Card Expiration', 'value' => { 'from' => '12-2019', 'to' => '2018-08-30T09:16:07Z' } }, { 'type' => 'default', 'field' => 'Subscription Plan', 'value' => { 'from' => 'Forest', 'to' => 'Estate' } }, { 'type' => 'default', 'field' => 'Subscription Currency', 'value' => { 'from' => 'EUR', 'to' => 'INR' } }] }]
  end

  def hypertrail_sample_response
    { links: [{ rel: 'next', href: 'http://hypertrail-dev.freshworksapi.com/api/v1/audit/account/shridartest1?nextToken=1600550144942760722', type: 'GET' }], data: [{ actor: { name: 'Admin', id: 37, type: 'agent' }, timestamp: 1_526_981_491_586, changes: { name: ['nasldasda', '2314211'], email: ['dslads@dsadasa.com', 'dsqslads@dsadasa.com'], ticket_permission: [1, 2], time_zone: ['Central Time (US & Canada)', 'Arizona'], scoreboard_level_id: [1, 3] }, object: { last_seen_at: nil, name: '2314211', failed_login_count: 0, active_since: nil, blocked_at: nil, customer_id: nil, email: 'dsqslads@dsadasa.com', last_active_at: nil, parent_id: 0, description: nil, job_title: '', current_login_ip: nil, privileges: '2596148429267413814265248181387263', whitelisted: false, signature_html: "<div dir=\"ltr\"><p><br></p>\n</div>", twitter_id: nil, signature: nil, user_role: nil, ticket_permission: 2, current_login_at: nil, user_id: 74_341, occasional: false, fb_profile_id: nil, google_viewer_id: nil, last_login_at: nil, points: nil, id: 54, account_id: 6, language: 'en', second_email: nil, last_login_ip: nil, extn: nil, login_count: 0, preferences: { agent_preferences: { shortcuts_mapping: [], falcon_ui: false, freshchat_token: nil, show_onBoarding: true, notification_timestamp: nil, shortcuts_enabled: true }, user_preferences: { was_agent: false, agent_deleted_forever: false } }, delta: true, external_id: nil, address: nil, available: false, blocked: false, created_at: '2018-05-22T09:29:59Z', import_id: nil, posts_count: 0, helpdesk_agent: true, updated_at: '2018-05-22T09:31:31Z', mobile: '', deleted_at: nil, time_zone: 'Arizona', scoreboard_level_id: 15, deleted: false, phone: '', unique_external_id: nil, active: false }, account_id: 'shridartest1', ip_address: '127.0.0.1', action: 'agent_update' }, { actor: { name: 'system', id: 0, type: 'system' }, timestamp: 1_526_980_693_092, changes: { agent_limit: [10, 9], state: ['active', 'trial'], renewal_period: [1, 3], card_number: ['************1111', 'dsadadasa'], amount: ['620.0', '49.0'], card_expiration: ['12-2019', '2018-08-30T09:16:07Z'], updated_at: ['2018-05-15T22:54:24+05:30', '2018-05-22T14:48:12+05:30'], subscription_plan_id: [5, 4], subscription_currency_id: [1, 2] }, object: { agent_limit: 9, state: 'trial', billing_id: nil, renewal_period: 3, free_agents: 0, card_number: 'dsadadasa', amount: 49, id: 6, account_id: 6, subscription_discount_id: nil, discount_expires_at: nil, created_at: '2015-05-16T11:06:06Z', subscription_affiliate_id: nil, card_expiration: '2018-08-30 09:16:07', updated_at: '2018-05-22T09:18:12Z', subscription_plan_id: 4, subscription_currency_id: 2, next_renewal_at: '2018-06-15T17:24:18Z', day_pass_amount: 3 }, account_id: 'shridartest1', ip_address: nil, action: 'subscription_update' }] }
  end

  def next_url
    'http://hypertrail-dev.freshworksapi.com/api/v1/audit/account/shridartest1?nextToken=1600550144942760722'
  end

  def audit_log_archived_params
    { version: 'private', format: 'json', from: (Date.today - 1).to_s, to: (Date.today - 4).to_s, receive_via: 'email', export_format: 'csv', archived: true }
  end

  def audit_log_export_failed_params
    { version: 'private', format: 'json', from: '2015-09-06', to: '2018-10-30', receive_via: 'email', export_format: 'xls' }
  end

  def audit_log_api_export_params
    { from: (Date.today - 1).to_s, to: (Date.today - 4).to_s, receive_via: 'api', export_format: 'csv' }
  end

  def filtered_job_id
    { 'job_id' => '16b6a771-519e-495b-a48c-5e5d82c23e1d' }
  end

  def archived_job_id
    { 'job_id' => '91736a8e-85c7-4942-b676-84769f622493' }
  end

  def api_export_response_job_id
    { 'job_id' => '7011d1fb-5e0e-491b-83d4-ac52b78c6ffc' }
  end
end
