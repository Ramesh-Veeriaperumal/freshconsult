
require_relative '../unit_test_helper'
require_relative '../test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'groups_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class NewPlanChangeWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include GroupsTestHelper
  include MemcacheKeys
  include TicketFieldsTestHelper
  def test_round_robin_load_balancing_drop_data
    create_test_account   
    group = @account.groups[0]
    group.capping_limit = 10
    group.ticket_assign_type = 1
    group.save
    SAAS::AccountDataCleanup.new(@account, ["round_robin_load_balancing"], "drop").perform_cleanup
    group.reload
    assert_equal group.capping_limit, 0
    assert_equal group.ticket_assign_type, 0
  end

  def test_round_robin_drop_data   
    create_test_account 
    group = @account.groups[0]
    group.capping_limit = 0
    group.ticket_assign_type = 1
    group.save
    SAAS::AccountDataCleanup.new(@account, ["round_robin"], "drop").perform_cleanup
    group.reload
    assert_equal group.capping_limit, 0
    assert_equal group.ticket_assign_type, 0
  end

  def test_marketplace_apps_cleanup
    create_test_account
    mock_installed_applications = [MiniTest::Mock.new]
    mock_app = MiniTest::Mock.new
    mock_app.expect(:slack?, true)
    mock_installed_applications.first.expect(:application, mock_app)
    mock_installed_applications.first.expect(:destroy, true)
    marketplace_response_body = {}.tap do |app|
      app['id'] = 1
      app['addon'] = {}
    end
    mock_marketplace_ext_response = {}.tap do |app|
      app['id'] = 1
      app['extension_id'] = 1
      app['addon'] = false
    end
    freshrequest_mock = MiniTest::Mock.new
    mock_marketplace_response = MiniTest::Mock.new
    FreshRequest::Client.stubs(:new).returns(freshrequest_mock)
    4.times do
      mock_marketplace_response.expect :status, 200
      mock_marketplace_response.expect :nil?, false
    end
    2.times do
      freshrequest_mock.expect :get, mock_marketplace_response
    end
    mock_marketplace_response.expect :body, [marketplace_response_body]
    mock_marketplace_response.expect :body, [mock_marketplace_ext_response]
    mock_marketplace_response.expect :body, [mock_marketplace_response]
    freshrequest_mock.expect :delete, mock_marketplace_response

    @account.stub(:installed_applications, mock_installed_applications) do
      SAAS::AccountDataCleanup.new(@account, ['custom_apps'], 'drop').perform_cleanup
    end
    assert mock_marketplace_response.verify
    assert freshrequest_mock.verify
  end

  def test_sitemap_drop_data
    assert_nothing_raised do
      create_test_account
      MemcacheKeys.expects(:delete_from_cache).with(format(SITEMAP_KEY, account_id: @account.id, portal_id: @account.main_portal.id)).once
      SAAS::AccountDataCleanup.new(@account, ['sitemap'], 'drop').perform_cleanup
    end
  end

  def test_ticket_fields_with_archived_fields_drop
    create_test_account
    create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city])
    create_custom_field_dropdown('test_custom_dropdown', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
    # Mark those custom fields as archived
    @account.ticket_fields.custom_fields.each do |tf|
      tf.deleted = true
      tf.save!
    end
    SAAS::AccountDataCleanup.new(@account, ['custom_ticket_fields'], 'drop').perform_cleanup
    assert_equal @account.ticket_fields_with_archived_fields.custom_fields, []
  ensure
    @account.ticket_fields_with_archived_fields.custom_fields.each(&:destroy)
  end

  def test_custom_source_soft_delete_drop_data
    create_test_account
    custom_source = @account.helpdesk_sources.visible.custom.last || create_custom_source
    SAAS::AccountDataCleanup.new(@account, ['custom_source'], 'drop').perform_cleanup
    custom_source.reload
    assert custom_source.deleted
  end

  def test_custom_source_reset_ticket_templates_data
    create_test_account
    custom_source = @account.helpdesk_sources.visible.custom.last || create_custom_source
    ticket_template = fetch_or_create_ticket_templates
    ticket_template.template_data['source'] = custom_source.account_choice_id.to_s
    ticket_template.save!
    SAAS::AccountDataCleanup.new(@account, ['custom_source'], 'drop').perform_cleanup
    custom_source.reload
    ticket_template.reload
    assert custom_source.deleted
    assert_equal ticket_template.template_data['source'], Helpdesk::Source.ticket_source_keys_by_token[:phone].to_s
  end

  def test_custom_source_fails_reset_ticket_templates_data
    create_test_account
    custom_source = @account.helpdesk_sources.visible.custom.last || create_custom_source
    ticket_template = fetch_or_create_ticket_templates
    ticket_template.template_data['source'] = custom_source.account_choice_id.to_s
    ticket_template.save!
    source_id = ticket_template.template_data['source']
    Helpdesk::TicketTemplate.any_instance.stubs(:template_data).raises(StandardError)
    SAAS::AccountDataCleanup.new(@account, ['custom_source'], 'drop').perform_cleanup
    custom_source.reload
    ticket_template.reload
    assert custom_source.deleted
    assert_not_equal source_id, Helpdesk::Source.ticket_source_keys_by_token[:phone].to_s
  end

  private

    def fetch_or_create_ticket_templates
      ticket_template = @account.ticket_templates.last || create_new_ticket_template
      ticket_template
    end

    def create_new_ticket_template
      ticket_template = FactoryGirl.build(:ticket_templates, template_params)
      ticket_template.save!
      ticket_template
    end

    def template_params
      {
        name: Faker::Name.name,
        description: Faker::Lorem.sentence(2),
        template_data: {
          subject: Faker::Lorem.sentence(2),
          status: '2',
          priority: '1'
        }.stringify_keys,
        account_id: @account.id,
        association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general],
        accessible_attributes: {
          access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
        }
      }
    end
end
