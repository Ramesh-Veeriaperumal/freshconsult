require_relative '../../../test_helper'
require_relative '../../../../spec/support/note_helper'

class JiraIssueTest < ActionView::TestCase
  include NoteHelper

  def setup
    @account = Account.first
    Account.stubs(:current).returns(Account.first)
    @jira_app = Integrations::JiraIssue.new(Integrations::InstalledApplication.new)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_fetch_jira_projects_issues
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns({})
    Integrations::JiraIssue.any_instance.stubs(:make_rest_call).returns(json_data: 'projects')
    issues = @jira_app.fetch_jira_projects_issues
    assert_equal 'projects', issues[:res_projects]
  end

  def test_create
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns({})
    Integrations::JiraIssue.any_instance.stubs(:make_rest_call).returns(json_data: { 'key' => 'jsondata' })
    Integrations::IntegratedResource.stubs(:createResource).returns(true)
    ::Integrations::JiraAccountConfig.stubs(:perform_async).returns(true)
    issue = @jira_app.create(body: 'body', local_integratable_id: 1, local_integratable_type: 'type')
    assert_equal true, issue
  end

  def test_create_no_integrated_resource
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns({})
    Integrations::JiraIssue.any_instance.stubs(:make_rest_call).returns(json_data: 'jsondata')
    issue = @jira_app.create(body: 'body', local_integratable_id: 1, local_integratable_type: 'type')
    assert_equal 'jsondata', issue[:json_data]
  end

  def test_create_err
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns({})
    Integrations::JiraIssue.any_instance.stubs(:make_rest_call).raises(StandardError.new('err'))
    issue = @jira_app.create(body: 'body', local_integratable_id: 1, local_integratable_type: 'type')
    assert_equal true, issue
  end

  def test_link_issue
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns({})
    Integrations::JiraIssue.any_instance.stubs(:make_rest_call).returns(json_data: { 'key' => 'jsondata' })
    Integrations::InstalledApplication.any_instance.stubs(:configs_customFieldId).returns(1)
    Integrations::InstalledApplication.any_instance.stubs(:configs_customFieldName).returns('dummyname')
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { customFieldId: 1 }.stringify_keys!)
    Integrations::IntegratedResource.stubs(:createResource).returns({})
    ::Integrations::JiraAccountConfig.stubs(:perform_async).returns(true)
    issue = @jira_app.link_issue(ticket_url: 'dummy_url', cloud_attachment: 'cloud_att')
    assert_equal 1, issue['custom_field']
  end

  def test_link_issue_params_exception
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns({})
    Integrations::JiraIssue.any_instance.stubs(:make_rest_call).returns(exception: 'remote_err')
    Integrations::InstalledApplication.any_instance.stubs(:configs_customFieldId).returns(1)
    Integrations::InstalledApplication.any_instance.stubs(:disable_observer).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save!).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:configs_customFieldName).returns('dummyname')
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { customFieldId: 1 }.stringify_keys!)
    Integrations::IntegratedResource.stubs(:createResource).returns({})
    ::Integrations::JiraAccountConfig.stubs(:perform_async).returns(true)
    app = Integrations::InstalledApplication.new
    app[:configs] = { inputs: { customFieldId: 1 }.stringify_keys! }
    jira_app = Integrations::JiraIssue.new(app)
    issue = jira_app.link_issue(ticket_url: 'dummy_url', cloud_attachment: 'cloud_att')
    assert_equal 'remote_err', issue[:exception]
  end

  def test_link_issue_custom_field_id
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns({})
    Integrations::JiraIssue.any_instance.stubs(:make_rest_call).returns(json_data: [{ 'name' => 'Freshdesk Tickets' }])
    Integrations::InstalledApplication.any_instance.stubs(:configs_customFieldId).returns(nil)
    Integrations::InstalledApplication.any_instance.stubs(:configs_customFieldName).returns('dummyname')
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { customFieldId: 1 }.stringify_keys!)
    Integrations::IntegratedResource.stubs(:createResource).returns({})
    ::Integrations::JiraAccountConfig.stubs(:perform_async).returns(true)
    issue = @jira_app.link_issue(ticket_url: 'dummy_url', cloud_attachment: 'cloud_att')
    assert_equal 1, issue['custom_field']
  end

  def test_link_issue_custom_field_id_empty_exception
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns({})
    Integrations::JiraIssue.any_instance.stubs(:make_rest_call).returns(json_data: [{ 'id' => 1, 'name' => 'Freshdesk Tickets' }])
    Integrations::InstalledApplication.any_instance.stubs(:configs_customFieldId).returns(nil)
    Integrations::InstalledApplication.any_instance.stubs(:configs_customFieldName).returns('dummyname')
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { customFieldId: 1 }.stringify_keys!)
    Integrations::IntegratedResource.stubs(:createResource).returns({})
    Integrations::InstalledApplication.any_instance.stubs(:save!).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:disable_observer).returns(true)
    ::Integrations::JiraAccountConfig.stubs(:perform_async).returns(true)
    app = Integrations::InstalledApplication.new
    app[:configs] = { inputs: { customFieldId: 1, customFieldName: 'dummy' }.stringify_keys! }
    jira_app = Integrations::JiraIssue.new(app)
    issue = jira_app.link_issue(ticket_url: 'dummy_url', cloud_attachment: 'cloud_att')
    assert_equal 1, issue['custom_field']
  end

  def test_link_issue_custom_field_id_exception
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns({})
    Integrations::JiraIssue.any_instance.stubs(:make_rest_call).returns(exception: 'exception')
    Integrations::InstalledApplication.any_instance.stubs(:configs_customFieldId).returns(nil)
    Integrations::InstalledApplication.any_instance.stubs(:configs_customFieldName).returns('dummyname')
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { customFieldId: 1 }.stringify_keys!)
    Integrations::IntegratedResource.stubs(:createResource).returns({})
    ::Integrations::JiraAccountConfig.stubs(:perform_async).returns(true)
    issue = @jira_app.link_issue(ticket_url: 'dummy_url', cloud_attachment: 'cloud_att')
    assert_equal 'exception', issue[:exception]
  end

  def test_link_issue_error
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns({})
    Integrations::JiraIssue.any_instance.stubs(:update).raises(StandardError.new('error'))
    Integrations::JiraIssue.any_instance.stubs(:make_rest_call).returns(json_data: { 'key' => 'jsondata' })
    Integrations::InstalledApplication.any_instance.stubs(:configs_customFieldId).returns(1)
    Integrations::InstalledApplication.any_instance.stubs(:configs_customFieldName).returns('dummyname')
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { customFieldId: 1 }.stringify_keys!)
    Integrations::IntegratedResource.stubs(:createResource).returns({})
    ::Integrations::JiraAccountConfig.stubs(:perform_async).returns(true)
    issue = @jira_app.link_issue(ticket_url: 'dummy_url', cloud_attachment: 'cloud_att')
    assert_equal true, issue
  end

  def test_unlink_issue
    Integrations::JiraIssue.any_instance.stubs(:update).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:configs_customFieldId).returns(1)
    Integrations::IntegratedResource.stubs(:deleteResource).returns({})
    issue = @jira_app.unlink_issue(id: 1)
    assert_equal :success, issue[:status]
  end

  def test_construct_attachment_params
    AwsWrapper::S3.stubs(:presigned_url).returns('dummy_url')
    Integrations::JiraIssue.any_instance.stubs(:open).returns(true)
    UploadIO.stubs(:new).returns(nil)
    Net::HTTP.any_instance.stubs(:request).returns(true)
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns(domain: 'testdomain.com', rest_url: 'index')
    Account.any_instance.stubs(:attachments).returns([Helpdesk::Attachment.new])
    att = @jira_app.construct_attachment_params(1, Account.first)
    assert_equal 1, att.count
    AwsWrapper::S3.unstub(:presigned_url)
  end

  def test_construct_attachment_params_timeout_error
    AwsWrapper::S3.stubs(:presigned_url).returns('dummy_url')
    Integrations::JiraIssue.any_instance.stubs(:open).raises(Timeout::Error.new('err'))
    Integrations::JiraIssue.any_instance.stubs(:params).returns(error: 'error')
    UploadIO.stubs(:new).returns(nil)
    Net::HTTP.any_instance.stubs(:request).returns(true)
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns(domain: 'testdomain.com', rest_url: 'index')
    Account.any_instance.stubs(:attachments).returns([Helpdesk::Attachment.new])
    att = @jira_app.construct_attachment_params(1, Account.first)
    assert_equal 1, att.count
    AwsWrapper::S3.unstub(:presigned_url)
  end

  def test_construct_attachment_params_error
    AwsWrapper::S3.stubs(:presigned_url).returns('dummy_url')
    Integrations::JiraIssue.any_instance.stubs(:open).raises(StandardError.new('err'))
    Integrations::JiraIssue.any_instance.stubs(:params).returns(error: 'error')
    UploadIO.stubs(:new).returns(nil)
    Net::HTTP.any_instance.stubs(:request).returns(true)
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns(domain: 'testdomain.com', rest_url: 'index')
    Account.any_instance.stubs(:attachments).returns([Helpdesk::Attachment.new])
    att = @jira_app.construct_attachment_params(1, Account.first)
    assert_equal 1, att.count
    AwsWrapper::S3.unstub(:presigned_url)
  end

  def test_construct_attachment_params_request_timeout_error
    AwsWrapper::S3.stubs(:presigned_url).returns('dummy_url')
    Integrations::JiraIssue.any_instance.stubs(:open).returns(true)
    Integrations::JiraIssue.any_instance.stubs(:params).returns(error: 'error')
    UploadIO.stubs(:new).returns(nil)
    Net::HTTP.any_instance.stubs(:start).raises(Timeout::Error.new('err'))
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns(domain: 'testdomain.com', rest_url: 'index')
    Account.any_instance.stubs(:attachments).returns([Helpdesk::Attachment.new])
    att = @jira_app.construct_attachment_params(1, Account.first)
  rescue Exception => e
    assert_equal nil, att
    AwsWrapper::S3.unstub(:presigned_url)
  end

  def test_construct_attachment_params_request_error
    AwsWrapper::S3.stubs(:presigned_url).returns('dummy_url')
    Integrations::JiraIssue.any_instance.stubs(:open).returns(true)
    Integrations::JiraIssue.any_instance.stubs(:params).returns(error: 'error')
    UploadIO.stubs(:new).returns(nil)
    Net::HTTP.any_instance.stubs(:start).raises(StandardError.new('err'))
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns(domain: 'testdomain.com', rest_url: 'index')
    Account.any_instance.stubs(:attachments).returns([Helpdesk::Attachment.new])
    att = @jira_app.construct_attachment_params(1, Account.first)
  rescue Exception => e
    assert_equal nil, att
    AwsWrapper::S3.unstub(:presigned_url)
  end

  def test_push_existing_notes_to_jira
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns({})
    Integrations::JiraIssue.any_instance.stubs(:make_rest_call).returns(json_data: { 'key' => 'jsondata' })
    Integrations::JiraIssue.any_instance.stubs(:set_integ_redis_key).returns(true)
    Integrations::JiraIssue.any_instance.stubs(:exclude_attachment?).returns(true)
    Helpdesk::Ticket.any_instance.stubs(:notes).returns(Helpdesk::Note.new)
    Helpdesk::Note.any_instance.stubs(:visible).returns(Helpdesk::Note.new)
    Helpdesk::Note.any_instance.stubs(:exclude_source).returns([Helpdesk::Note.new])
    note = @jira_app.push_existing_notes_to_jira(1, Account.first.tickets.last)
    assert_equal Helpdesk::Note, note.first.class
  end

  def test_delete
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns({})
    Integrations::JiraIssue.any_instance.stubs(:make_rest_call).returns(json_data: { 'key' => 'jsondata' })
    Integrations::IntegratedResource.stubs(:delete_resource_by_remote_integratable_id).returns(true)
    deleted = @jira_app.delete(remote_integratable_id: 1)
    assert_equal true, deleted[:status]
  end

  def test_delete_with_exception
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns({})
    Integrations::JiraIssue.any_instance.stubs(:make_rest_call).returns(exception: true)
    Integrations::IntegratedResource.stubs(:delete_resource_by_remote_integratable_id).returns(true)
    deleted = @jira_app.delete(remote_integratable_id: 1)
    assert_equal true, deleted[:exception]
  end

  def test_authenticate
    Integrations::InstalledApplication.any_instance.stubs(:configs_username).returns('usr')
    Integrations::InstalledApplication.any_instance.stubs(:configsdecrypt_password).returns('pwd')
    Integrations::InstalledApplication.any_instance.stubs(:configs_domain).returns('domain')
    Integrations::JiraIssue.any_instance.stubs(:make_rest_call).returns(true)
    auth = @jira_app.authenticate
    assert_equal true, auth
  end

  def test_update_status
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns({})
    Integrations::JiraIssue.any_instance.stubs(:make_rest_call).returns(json_data: { 'transitions' => [{ 'id' => 1, 'name' => 'new status' }] })
    status = @jira_app.update_status(1, 'new status')
    assert_equal true, status[:json_data].present?
  end

  def test_update_status_invalid
    Integrations::JiraIssue.any_instance.stubs(:construct_params_for_http).returns({})
    Integrations::JiraIssue.any_instance.stubs(:make_rest_call).returns(json_data: { 'transitions' => [{ 'id' => 1, 'name' => 'new status' }] })
    status = @jira_app.update_status(1, 'new status falsy')
    assert_equal true, status
  end
end
