require_relative '../test_helper'
['ticket_helper.rb', 'group_helper.rb', 'social_tickets_creation_helper.rb', 'contact_fields_helper.rb', 'email_configs_helper.rb'].each { |file| require Rails.root.join("spec/support/#{file}") }
['solutions_test_helper.rb', 'account_test_helper.rb', 'users_test_helper.rb'].each { |file| require Rails.root.join("test/core/helpers/#{file}") }
['facebook_test_helper.rb', 'ticket_fields_test_helper.rb', 'solutions_approvals_test_helper.rb'].each { |file| require Rails.root.join("test/api/helpers/#{file}") }

class AccountDataCleanupTest < ActionView::TestCase
  include AccountTestHelper
  include TicketHelper
  include GroupHelper
  include FacebookTestHelper
  include CoreUsersTestHelper
  include TicketFieldsTestHelper
  include SocialTicketsCreationHelper
  include ContactFieldsHelper
  include EmailConfigsHelper
  include SolutionsApprovalsTestHelper
  include CoreSolutionsTestHelper

  def test_account_cleanup_drop_data
    # Observer rules
    @account = create_new_account("#{Faker::Lorem.word}#{rand(10000)}", Faker::Internet.email)
    @account.reload
    va_rule = FactoryGirl.build(:va_rule, name: "created by #{Faker::Name.name}", description: Faker::Lorem.sentence(2), action_data: [{ name: 'priority', value: '3' }], filter_data: { events: [{ name: 'priority', from: '--', to: '--' }], performer: { 'type' => '1' }, conditions: [{ name: 'ticket_type', operator: 'in', value: ['Problem', 'Question'] }] }, account_id: @account.id, rule_type: VAConfig::OBSERVER_RULE)
    va_rule.save(validate: false)

    # Ticket watchers
    ticket = @account.tickets.first
    add_watchers_to_ticket(@account, agent_id: [@account.agents.first.id], ticket_id: ticket.id)

    # Facebook pages
    2.times do
      create_test_facebook_page(@account)
    end

    # Round robin feature
    Account.any_instance.stubs(:round_robin_enabled?).returns(true)
    group = create_group @account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:skill_based]

    # Occasional agent
    user = add_agent(@account)
    agent = user.agent
    agent.occasional = true
    agent.save

    # Email config
    email_config = create_email_config
    email_config.primary_role = false
    email_config.save

    # Ticket custom field
    create_custom_field(Faker::Lorem.characters(5), 'checkbox')

    # Contact custom field
    create_contact_field(cf_params(type: 'paragraph', field_type: 'custom_paragraph', label: Faker::Lorem.word, editable_in_signup: 'true'))

    # Company custom field
    create_company_field(company_params(type: 'text', field_type: 'custom_text', label: Faker::Lorem.word, required_for_agent: true))

    # Stub parent_child_tickets feature
    Account.any_instance.stubs(:parent_child_tickets_enabled?).returns(true)

    # Create ticket export activity
    export_activity = ScheduledExport::Activity.new(name: Faker::Lorem.word, description: Faker::Lorem.characters(20), active: 1)
    export_activity.save

    # Add widget position for unique_external_id column
    field = @account.contact_form.default_fields.where(name: 'unique_external_id').first
    field.field_options = { 'widget_position' => '1' }
    field.save

    @account.reload
    assert_not_nil @account.all_observer_rules.find_by_id(va_rule.id)
    assert_equal @account.ticket_subscriptions.length, 1
    assert_equal @account.contact_form.custom_contact_fields.length, 1
    assert_equal @account.company_form.custom_company_fields.length, 1

    SAAS::AccountDataCleanup.new(@account, ['create_observer', 'supervisor', 'basic_twitter', 'add_watcher', 'basic_facebook', 'skill_based_round_robin', 'occasional_agent', 'custom_status', 'custom_ticket_fields', 'custom_contact_fields', 'custom_company_fields', 'custom_ticket_views', 'multi_timezone', 'multiple_emails', 'multi_product', 'shared_ownership_toggle', 'shared_ownership', 'link_tickets', 'parent_child_tickets_toggle', 'auto_ticket_export', 'multiple_companies_toggle', 'support_bot', 'custom_dashboard', 'hipaa', 'rebranding', 'customer_slas', 'unique_contact_identifier', 'link_tickets_toggle', 'ticket_activity_export', 'disable_old_ui', 'article_versioning'], 'drop').perform_cleanup
    @account.reload
    assert_nil @account.all_observer_rules.find_by_id(va_rule.id)
    assert_equal @account.all_supervisor_rules.length, 0
    assert_equal @account.ticket_subscriptions.length, 0
    assert_equal @account.facebook_pages.length, 2
    assert_equal @account.agents.where(occasional: true).length, 0
    assert_equal @account.ticket_statuses.where(is_default: false, deleted: false).length, 0
    assert_equal @account.ticket_fields.where(default: false).length, 0
    assert_equal @account.contact_form.custom_contact_fields.length, 0
    assert_equal @account.company_form.custom_company_fields.length, 0
    assert_equal @account.solution_article_versions.count, 0

    Account.any_instance.stubs(:features_included?).raises(StandardError)
    SAAS::AccountDataCleanup.new(@account, ['custom_apps'], 'drop').perform_cleanup
  ensure
    Account.any_instance.unstub(:round_robin_enabled?)
    Account.any_instance.unstub(:parent_child_tickets_enabled?)
    Account.any_instance.unstub(:features_included?)
    Account.current.destroy if !Account.current.nil? && Account.current.id != 1 && !Account.current.id.nil?
  end

  def test_skill_based_round_robin_drop_data_without_round_robin_feature
    @account = create_new_account("#{Faker::Lorem.word}#{rand(10000)}", Faker::Internet.email)
    Account.any_instance.stubs(:features?).with(:round_robin).returns(false)
    Account.any_instance.stubs(:features?).with(:round_robin_load_balancing).returns(false)
    group = create_group @account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:skill_based]
    SAAS::AccountDataCleanup.new(@account, ['skill_based_round_robin'], 'drop').perform_cleanup
    assert_equal @account.reload.groups.skill_based_round_robin_enabled.length, 0 if @account.try(:id)
  ensure
    Account.any_instance.unstub(:features?)
    Account.current.destroy if !Account.current.nil? && Account.current.id != 1 && !Account.current.id.nil?
  end

  def test_account_cleanup_add_data
    Marketplace::MarketPlaceObject.any_instance.stubs(:get_api).returns(nil)
    @account = create_new_account("#{Faker::Lorem.word}#{rand(10000)}", Faker::Internet.email)
    # Twitter handle
    get_twitter_handle

    # Create test installed application
    installed_app = @account.installed_applications.new
    parent_child_ticket_application = Integrations::Application.find_by_name('parent_child_tickets')
    installed_app.application_id = parent_child_ticket_application.id
    installed_app.skip_callbacks = true
    installed_app.save

    # Delete company field
    @account.ticket_fields_from_cache.find { |tf| tf.name == 'company' }.destroy
    @account.contact_form.default_fields.find { |tf| tf.name == 'unique_external_id' }.destroy
    @account.reload

    SAAS::AccountDataCleanup.new(@account, ['smart_filter', 'shared_ownership', 'link_tickets', 'parent_child_tickets_toggle', 'parent_child_tickets', 'multiple_companies_toggle', 'tam_default_fields', 'unique_contact_identifier', 'custom_dashboard', 'link_tickets_toggle', 'article_versioning'], 'add').perform_cleanup
  ensure
    Marketplace::MarketPlaceObject.any_instance.unstub(:get_api)
    Account.current.destroy if !Account.current.nil? && Account.current.id != 1 && !Account.current.id.nil?
  end

  def test_handle_custom_status_drop_data
    @account = create_new_account("#{Faker::Lorem.word}#{rand(10000)}", Faker::Internet.email)
    new_status = Helpdesk::TicketStatus.new(name: 'temp', customer_display_name: 'temp', stop_sla_timer: false, deleted: false, is_default: false, account_id: @account.id, ticket_field_id: 5)
    new_status.save
    ticket_field = @account.ticket_fields.where(field_type: 'default_status')[0]
    updated_at = ticket_field.updated_at
    sleep(1)
    SAAS::AccountDataCleanup.new(Account.current, ['custom_status'], 'drop').perform_cleanup
    ticket_field = @account.ticket_fields.where(field_type: 'default_status')[0]
    non_deleted_custom_statuses = @account.ticket_statuses.where(is_default: false).find { |status| status.deleted == false }
    assert ticket_field.updated_at > updated_at # to check if perform_cleanup updates ticket_field
    assert_nil non_deleted_custom_statuses
  end

  def test_handle_custom_password_policy_drop_data
    @account = Account.first || create_new_account("#{Faker::Lorem.word}#{rand(10_000)}", Faker::Internet.email)
    @account.make_current
    Account.any_instance.stubs(:agent_password_policy).returns(nil)
    account_data_cleanup = SAAS::AccountDataCleanup.new(Account.current, ['custom_password_policy'], 'drop')
    account_data_cleanup.perform_cleanup
    @account.agent_password_policy&.reload
    account_data_cleanup.expects(:rescue).never
  ensure
    Account.any_instance.unstub(:agent_password_policy)
    puts Account.first == Account.last
    @account.try(:destroy) unless Account.first
    Account.reset_current_account
  end

  def test_handle_custom_password_policy_drop_data_with_agent_password_policy
    @account = Account.first || create_new_account("#{Faker::Lorem.word}#{rand(10_000)}", Faker::Internet.email)
    @account.make_current
    @account.build_default_password_policy(PasswordPolicy::USER_TYPE[:agent]).save!
    account_data_cleanup = SAAS::AccountDataCleanup.new(Account.current, ['custom_password_policy'], 'drop')
    account_data_cleanup.perform_cleanup

    @account.agent_password_policy.reload
    account_data_cleanup.expects(:rescue).never
    policy = @account.agent_password_policy
    assert_equal policy.configs, FDPasswordPolicy::Constants::DEFAULT_CONFIGS
  ensure
    @account.agent_password_policy.destroy
    @account.try(:destroy) unless Account.first
    Account.reset_current_account
  end

  def test_handle_article_approval_workflow_drop_data
    @account = Account.first
    @account.make_current

    category = create_category(portal_id: @account.main_portal.id)
    params = {
      title: "Test #{rand(10_000)}",
      description: "Test #{rand(10_000)}",
      folder_id: create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id).id,
      status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
    }

    create_article(params)

    get_in_review_article
    assert @account.helpdesk_approvals.solution_approvals.count != 0
    SAAS::AccountDataCleanup.new(@account, ['article_approval_workflow'], 'drop').perform_cleanup
    assert_equal @account.reload.helpdesk_approvals.solution_approvals.count, 0
  end

  def test_handle_article_approval_workflow_drop_data_with_exception
    @account = Account.first
    @account.make_current

    category = create_category(portal_id: @account.main_portal.id)
    params = {
      title: "Test #{rand(10_000)}",
      description: "Test #{rand(10_000)}",
      folder_id: create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id).id,
      status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
    }

    create_article(params)

    get_in_review_article
    assert @account.helpdesk_approvals.solution_approvals.count != 0
    Helpdesk::Approval.any_instance.stubs(:destroy).raises(StandardError)
    assert_nothing_raised do
      SAAS::AccountDataCleanup.new(@account, ['article_approval_workflow'], 'drop').perform_cleanup
      assert @account.reload.helpdesk_approvals.solution_approvals.count != 0
    end
  ensure
    Helpdesk::Approval.any_instance.unstub(:destroy)
  end

  def test_handle_solutions_templates_drop_data
    @account = create_new_account("#{Faker::Lorem.word}#{rand(10_000)}", Faker::Internet.email)
    ::Solution::TemplatesMigrationWorker.expects(:perform_async).with('action': 'drop').once
    SAAS::AccountDataCleanup.new(@account, ['solutions_templates'], 'drop').perform_cleanup
  end

  def test_handle_solutions_templates_add_data
    @account = create_new_account("#{Faker::Lorem.word}#{rand(10_000)}", Faker::Internet.email)
    ::Solution::TemplatesMigrationWorker.expects(:perform_async).with('action': 'add').once
    SAAS::AccountDataCleanup.new(@account, ['solutions_templates'], 'add').perform_cleanup
  end
end
