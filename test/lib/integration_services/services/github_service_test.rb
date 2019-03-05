require_relative '../../../api/unit_test_helper'

class GithubServiceTest < ActionView::TestCase
  def setup
    Account.stubs(:current).returns(Account.first)
    User.stubs(:current).returns(Account.first.users.first)
  end

  def teardown
    super
    Account.unstub(:current)
    User.unstub(:current)
  end

  def test_fetch_server_url
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::GithubService.any_instance.stubs(:configs).returns({})
    url = ::IntegrationServices::Services::GithubService.new(app, { type: 'test' }, {}).server_url
    assert_equal 'https://api.github.com', url
  end

  def test_receive_create_issue
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { map_type_to_label: 'true' }.stringify_keys!)
    IntegrationServices::Services::Github::GithubIssueResource.any_instance.stubs(:create).returns(issue: 'test_issue')
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).returns(Integrations::IntegratedResource.new)
    Integrations::IntegratedResource.any_instance.stubs(:create).returns(Integrations::IntegratedResource.new)
    Integrations::IntegratedResource.any_instance.stubs(:local_integratable).returns(Account.first.tickets.first)
    Integrations::InstalledApplication.any_instance.stubs(:configs_freshdesk_comment_sync).returns('true')
    Integrations::GithubWorker.stubs(:perform_async).returns(true)
    Helpdesk::Note.any_instance.stubs(:save_note).returns(true)
    app = Integrations::InstalledApplication.new
    issue = ::IntegrationServices::Services::GithubService.new(app, { local_integratable_id: Account.first.tickets.first.try(:id), options: {} }, {}).receive_create_issue
    assert_equal Account.first.id, issue['account_id']
  end

  def test_receive_create_issue_errors
    Integrations::InstalledApplication.any_instance.stubs(:account).raises(IntegrationServices::Errors::RemoteError.new('remote error'))
    app = Integrations::InstalledApplication.new
    issue = ::IntegrationServices::Services::GithubService.new(app, { local_integratable_id: Account.first.tickets.first.try(:id), options: {} }, {}).receive_create_issue
    assert_equal 'remote error', issue[:message]
  end

  def test_receive_issue
    IntegrationServices::Services::Github::GithubIssueResource.any_instance.stubs(:issue).returns({})
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).returns(Integrations::IntegratedResource.new)
    Integrations::IntegratedResource.any_instance.stubs(:first_integrated_resource).returns([Account.first.tickets.first])
    Helpdesk::Ticket.any_instance.stubs(:local_integratable).returns(Account.first.tickets.first)
    app = Integrations::InstalledApplication.new
    issue = ::IntegrationServices::Services::GithubService.new(app, { local_integratable_id: Account.first.tickets.first.try(:id), options: {} }, {}).receive_issue
    assert_equal true, issue['tracker_ticket'].present?
  end

  def test_receive_issue_error
    IntegrationServices::Services::Github::GithubIssueResource.any_instance.stubs(:issue).raises(IntegrationServices::Errors::RemoteError.new('remote error'))
    app = Integrations::InstalledApplication.new
    issue = ::IntegrationServices::Services::GithubService.new(app, { local_integratable_id: Account.first.tickets.first.try(:id), options: {} }, {}).receive_issue
    assert_equal 'remote error', issue[:message]
  end

  def test_receive_link_issue
    IntegrationServices::Services::Github::GithubIssueResource.any_instance.stubs(:issue).returns({})
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).returns(Integrations::IntegratedResource.new)
    Integrations::IntegratedResource.any_instance.stubs(:first_integrated_resource).returns([Integrations::IntegratedResource.new])
    Integrations::IntegratedResource.any_instance.stubs(:remote_integratable_id).returns(1)
    Integrations::IntegratedResource.any_instance.stubs(:local_integratable).returns(Account.first.tickets.first)
    IntegrationServices::Services::Github::GithubIssueResource.any_instance.stubs(:add_comment).returns({})
    IntegrationServices::Services::GithubService.any_instance.stubs(:set_integ_redis_key).returns(true)
    Integrations::IntegratedResource.any_instance.stubs(:create).returns(Integrations::IntegratedResource.new)
    Helpdesk::Note.any_instance.stubs(:save_note).returns(true)
    app = Integrations::InstalledApplication.new
    issue = ::IntegrationServices::Services::GithubService.new(app, { local_integratable_id: Account.first.tickets.first.try(:id), number: 1 }, {}).receive_link_issue
    assert_equal true, issue['account_id'].present?
  end

  def test_receive_link_remote_err
    IntegrationServices::Services::Github::GithubIssueResource.any_instance.stubs(:issue).raises(IntegrationServices::Errors::RemoteError.new('remote error'))
    app = Integrations::InstalledApplication.new
    issue = ::IntegrationServices::Services::GithubService.new(app, { local_integratable_id: Account.first.tickets.first.try(:id), options: {} }, {}).receive_link_issue
    assert_equal 'remote error', issue[:message]
  end

  def test_receive_unlink_issue
    IntegrationServices::Services::Github::GithubIssueResource.any_instance.stubs(:issue).returns({})
    Integrations::IntegratedResource.any_instance.stubs(:first_integrated_resource).returns([Integrations::IntegratedResource.new])
    Integrations::IntegratedResource.any_instance.stubs(:local_integratable).returns(Account.first.tickets.first)
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).returns(Integrations::IntegratedResource.new)
    Integrations::IntegratedResource.any_instance.stubs(:find).returns(Integrations::IntegratedResource.new)
    IntegrationServices::Services::Github::GithubIssueResource.any_instance.stubs(:add_comment).returns({})
    IntegrationServices::Services::Github::GithubIssueResource.any_instance.stubs(:issue).returns({})
    Integrations::IntegratedResource.any_instance.stubs(:remote_integratable_id).returns('1')
    IntegrationServices::Services::GithubService.any_instance.stubs(:set_integ_redis_key).returns(true)
    Helpdesk::Note.any_instance.stubs(:save_note).returns(true)
    Integrations::IntegratedResource.any_instance.stubs(:destroy).returns(true)
    app = Integrations::InstalledApplication.new
    issue = ::IntegrationServices::Services::GithubService.new(app, { local_integratable_id: Account.first.tickets.first.try(:id), number: 1 }, {}).receive_unlink_issue
    assert_equal 'Success', issue[:message]
  end

  def test_receive_unlink_issue_remote_err
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).raises(IntegrationServices::Errors::RemoteError.new('remote error'))
    app = Integrations::InstalledApplication.new
    issue = ::IntegrationServices::Services::GithubService.new(app, { local_integratable_id: Account.first.tickets.first.try(:id), number: 1 }, {}).receive_unlink_issue
    assert_equal 'remote error', issue[:message]
  end

  def test_receive_unlink_issue_exception
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).raises(Exception.new('exception'))
    app = Integrations::InstalledApplication.new
    issue = ::IntegrationServices::Services::GithubService.new(app, { local_integratable_id: Account.first.tickets.first.try(:id), number: 1 }, {}).receive_unlink_issue
    assert_equal 'Error unlinking the ticket from the github issue', issue[:message]
  end

  def test_receive_milestones
    IntegrationServices::Services::Github::GithubRepoResource.any_instance.stubs(:list_milestones).returns(true)
    app = Integrations::InstalledApplication.new
    milestones = ::IntegrationServices::Services::GithubService.new(app, { number: 1 }, {}).receive_milestones
    assert_equal true, milestones
  end

  def test_receive_milestones_err
    IntegrationServices::Services::Github::GithubRepoResource.any_instance.stubs(:list_milestones).raises(IntegrationServices::Errors::RemoteError.new('remote error'))
    app = Integrations::InstalledApplication.new
    milestones = ::IntegrationServices::Services::GithubService.new(app, { number: 1 }, {}).receive_milestones
    assert_equal 'remote error', milestones[:message]
  end

  def test_receive_repos
    IntegrationServices::Services::Github::GithubRepoResource.any_instance.stubs(:list_repos).returns(true)
    app = Integrations::InstalledApplication.new
    repos = ::IntegrationServices::Services::GithubService.new(app, { number: 1 }, {}).receive_repos
    assert_equal true, repos
  end

  def test_receive_add_webhooks
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: {})
    Integrations::InstalledApplication.any_instance.stubs(:configs_webhooks).returns({})
    Integrations::InstalledApplication.any_instance.stubs(:save!).returns(true)
    IntegrationServices::Services::Github::GithubWebhookResource.any_instance.stubs(:create_webhook).returns({ id: 1 }.stringify_keys!)
    app = Integrations::InstalledApplication.new
    webhook_response = ::IntegrationServices::Services::GithubService.new(app, { events: 'test_event', repositories: ['test'] }, {}).receive_add_webhooks
    assert_equal true, webhook_response
  end

  def test_receive_delete_webhooks
    IntegrationServices::Services::Github::GithubWebhookResource.any_instance.stubs(:delete_webhook).returns(true)
    app = Integrations::InstalledApplication.new
    webhook_response = ::IntegrationServices::Services::GithubService.new(app, { webhooks: { 'test': 1 } }, {}).receive_delete_webhooks
    assert_equal true, webhook_response[:test].present?
  end

  def test_receive_sync_comment_to_github
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { freshdesk_comment_sync: 'true' }.stringify_keys!)
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).returns(Integrations::IntegratedResource.new)
    Integrations::IntegratedResource.any_instance.stubs(:find_by_local_integratable_id).returns(Account.first.notes.first)
    Integrations::IntegratedResource.any_instance.stubs(:first_integrated_resource).returns([Account.first.notes.first])
    IntegrationServices::Services::GithubService.any_instance.stubs(:set_integ_redis_key).returns(true)
    Helpdesk::Note.any_instance.stubs(:remote_integratable_id).returns('1/issues/1')
    IntegrationServices::Services::Github::GithubIssueResource.any_instance.stubs(:add_comment).returns({})
    app = Integrations::InstalledApplication.new
    sync_comment = ::IntegrationServices::Services::GithubService.new(app, { act_on_object: Account.first.notes.first }, {}).receive_sync_comment_to_github
    assert_equal true, sync_comment
  end

  def test_receive_issue_comment_webhook
    Integrations::InstalledApplication.any_instance.stubs(:configs_github_comment_sync).returns('true')
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).returns(Integrations::IntegratedResource.new)
    Integrations::IntegratedResource.any_instance.stubs(:first_integrated_resource).returns([Account.first.notes.first])
    Helpdesk::Note.any_instance.stubs(:remote_integratable_id).returns('1/issues/1')
    Helpdesk::Note.any_instance.stubs(:local_integratable).returns(Account.first.tickets.first)
    Helpdesk::Note.any_instance.stubs(:responder).returns(nil)
    Helpdesk::Note.any_instance.stubs(:save_note).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:user_credentials).returns(Account.first.users.first)
    IntegrationServices::Services::Github::GithubUserResource.any_instance.stubs(:get_user).returns({})
    User.any_instance.stubs(:signup!).returns(true)
    User.any_instance.stubs(:create).returns(true)
    User.any_instance.stubs(:find_by_remote_user_id).returns(nil)
    app = Integrations::InstalledApplication.new
    comment_webhook = ::IntegrationServices::Services::GithubService.new(app, { repository: { full_name: 'test_repo' }.stringify_keys!,
                                                                                issue: { number: 1 }.stringify_keys!,
                                                                                comment: {
                                                                                  body: 'test body',
                                                                                  url: 'testurl',
                                                                                  user: { id: 1, login: 'user_login' }.stringify_keys!
                                                                                }.stringify_keys! }.stringify_keys!,
                                                                         {}).receive_issue_comment_webhook
    assert_equal :ok, comment_webhook[1]
  end

  def test_receive_issues_webhook
    Integrations::InstalledApplication.any_instance.stubs(:configs_github_status_sync).returns('present')
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).returns(Integrations::IntegratedResource.new)
    Integrations::IntegratedResource.any_instance.stubs(:first_integrated_resource).returns([Account.first.tickets.first])
    Helpdesk::Ticket.any_instance.stubs(:local_integratable).returns(Account.first.tickets.first)
    Helpdesk::Ticket.any_instance.stubs(:update_ticket_attributes).returns(true)
    app = Integrations::InstalledApplication.new
    issue_webhook = ::IntegrationServices::Services::GithubService.new(app, { repository: { full_name: 'test_repo' }.stringify_keys!,
                                                                              issue: { number: 1 }.stringify_keys!,
                                                                              github: { action: 'closed' }.stringify_keys! }.stringify_keys!,
                                                                       {}).receive_issues_webhook
    assert_equal :ok, issue_webhook[1]
  end

  def test_receive_install
    VaRule.any_instance.stubs(:save!).returns(true)
    Integrations::AppBusinessRule.stubs(:find_by_installed_application_id).returns(false)
    app = Integrations::InstalledApplication.new
    install_app = ::IntegrationServices::Services::GithubService.new(app, {}, {}).receive_install
    assert_equal true, install_app
  end

  def test_receive_uninstall
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { webhooks: { 'test': 1 } }.stringify_keys!)
    IntegrationServices::Services::Github::GithubWebhookResource.any_instance.stubs(:delete_webhook).returns(true)
    app = Integrations::InstalledApplication.new
    install_app = ::IntegrationServices::Services::GithubService.new(app, {}, {}).receive_uninstall
    assert_equal true, install_app[:test].present?
  end
end
