require_relative '../test_helper'
require 'faker'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('spec', 'support', 'company_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class UserTest < ActiveSupport::TestCase
  include UsersHelper
  include CompanyHelper
  include AccountTestHelper
  include PrivilegesHelper

  def setup
    super
    @account = create_test_account if @account.nil?
    @account.make_current
    @account.tags.delete_all
    @account.tag_uses.delete_all
  end

  def test_user_allowed_for_password_reset
    user = add_new_user(@account)
    assert_equal user.allow_password_reset?, true
  end

  def test_user_with_fb_id
    user = add_new_user_with_fb_id(@account)
    assert_equal user.is_user_social(:medium), "https://graph.facebook.com/#{user.fb_profile_id}/picture?type=large"
  end

  def test_ebay_user
    user = add_new_user(@account)
    assert_equal user.ebay_user?, false
  end

  def test_user_has_edit_access
    user = add_new_user(@account)
    assert_equal user.has_edit_access?(user.id), false
  end

  def test_user_segments
    skip('failing test cases')
    user = add_new_user(@account)
    assert_equal user.segments.length, 15
  end

  def test_user_find_by_email_and_name
    user = add_new_user(@account)
    user_by_email = @account.users.find_by_email_or_name(user.email)
    user_by_name = @account.users.find_by_email_or_name(user.name)
    assert_equal user_by_email, user_by_name
  end

  def test_user_chk_email_validation
    user = add_new_user(@account)
    assert_equal user.chk_email_validation?, true
  end

  def test_add_tag
    user = add_new_user(@account)
    tag = Helpdesk::Tag.new(name: Faker::Name.name)
    user.add_tag(tag)
    assert_equal user.tags.last.name, tag.name
  end

  def test_user_tagged_with_invalid_id
    user = add_new_user(@account)
    User.any_instance.stubs(:tag_uses).returns([Helpdesk::TagUse.new])
    assert_equal user.tagged?(1_432_432_432), false
  ensure
    User.any_instance.unstub(:tag_uses)
  end

  def test_user_tagged_with_valid_id
    user = add_new_user(@account)
    tag = Helpdesk::Tag.new(name: Faker::Name.name)
    user.add_tag(tag)
    assert_equal user.tagged?(tag.id), true
  end

  def test_user_has_valid_freshid_login
    user = add_new_user(@account)
    Freshid::Login.any_instance.stubs(:authenticate_user).returns(true)
    Freshid::Login.any_instance.stubs(:valid_credentials?).returns(true)
    assert_equal user.safe_send(:valid_freshid_login?, Faker::Lorem.words(3)), true
  ensure
    Freshid::Login.any_instance.unstub(:authenticate_user)
    Freshid::Login.any_instance.unstub(:valid_credentials?)
  end

  def test_user_update_with_fid_password
    user = @account.users.last
    assert_equal user.exist_in_db?, true
    user.safe_send(:update_with_fid_password, Faker::Name.name)
    user.safe_send(:backup_user_changes)
    assert_equal user.safe_send(:password_updated?), false
  end

  def test_user_converted_to_agent_or_email_updated
    user = @account.users.last
    User.update_posts_count(user.id)
    user.safe_send(:backup_user_changes)
    assert_equal user.safe_send(:converted_to_agent_or_email_updated?), false
  end

  def test_user_search_display
    user = add_new_user(@account)
    User.any_instance.stubs(:excerpts).returns(user)
    assert_equal User.search_display(user), "#{user.name} - #{user.email}"
  ensure
    User.any_instance.unstub(:excerpts)
  end

  def test_user_filter
    user = add_new_user(@account)
    assert_not_nil User.filter(Faker::Name.name, 1)
    assert_not_nil User.filter(Faker::Name.name, 1, 'blocked')
  end

  def test_run_without_current_user
    User.run_without_current_user do
      assert_nil User.current
    end
  end

  def test_user_filter_railses_exception
    user = add_new_user(@account)
    assert_raises(RuntimeError) do
      User.filter(Faker::Name.name, 0, 'all')
    end
  end

  def test_run_without_current_user_raises_exception
    User.stubs(:reset_current_user).raises(Exception)
    NewRelic::Agent.stubs(:notice_error).returns(true)
    assert_raises(Exception) do
      User.run_without_current_user do
        assert_not_nil User.current
      end
    end
  ensure
    User.unstub(:reset_current_user)
    NewRelic::Agent.unstub(:notice_error)
  end

  def test_user_params
    user = add_new_user(@account)
    Account.any_instance.stubs(:unique_contact_identifier_enabled?).returns(true)
    assert_empty user.client_managers_for_export
    assert_nil user.company_ids_str
    assert_empty user.client_manager_companies
    assert_empty user.recent_tickets
    assert_nil user.update_search_index
    assert_equal user.moderator_of?(@account.forums.first), false
    assert_equal user.user_time_zone, 'Chennai'
    assert_equal user.assign_external_id(1), 1
    assert_not_nil user.display_name
    assert_equal user.developer?, false
    assert_equal user.api_assumable?, false
    assert_equal user.first_login?, true
    assert_not_nil user.get_info
    assert_equal user.twitter_style_id, '@'
    assert_empty User.search_by_name(@account.users.first.name, @account.id)
    User.reset_current_user
    assert_nil User.current
    Account.current.users.first.make_current
  ensure
    Account.any_instance.unstub(:unique_contact_identifier_enabled?)
  end

  def test_user_quest_params
    user = add_new_user(@account)
    assert_equal user.available_quests.length, 7
    assert_nil user.achieved_quest(@account.quests.first)
    User.any_instance.stubs(:achieved_quest).returns(@account.quests.first)
    assert_not_nil user.badge_awarded_at(@account.quests.first)
  ensure
    User.any_instance.unstub(:achieved_quest)
  end

  def test_user_account_url_with_blank_url_from_cache
    user = @account.users.first
    Portal.any_instance.stubs(:portal_url).returns('localhost.freshdesk.com')
    Portal.any_instance.stubs(:ssl_enabled?).returns(true)
    assert_equal user.url_protocol, 'https'
  ensure
    Portal.any_instance.unstub(:portal_url)
    Portal.any_instance.unstub(:ssl_enabled?)
  end

  def test_user_reset_tokens
    user = add_new_user(@account)
    assert_not_nil user.company_name = ''
    User.any_instance.stubs(:save).returns(false)
    User.any_instance.stubs(:customer?).returns(false)
    assert_equal user.make_customer, false
    assert_equal user.reset_tokens!, 0
  ensure
    User.any_instance.unstub(:save)
    User.any_instance.unstub(:customer?)
  end

  def test_user_freshid_params
    Account.any_instance.stubs(:try).returns(true)
    User.any_instance.stubs(:freshid_enabled_account?).returns(true)
    Freshid::User.any_instance.stubs(:destroy).returns(true)
    user = add_new_user(@account)
    freshid_user = user.create_freshid_user!
    assert_nil freshid_user
    user.stubs(:uuid).returns(1)
    user.stubs(:full_name).returns(Faker::Name.name)
    assert_equal user.sync_profile_from_freshid(user), true
    assert_nil user.destroy_freshid_user
  ensure
    Account.any_instance.unstub(:try)
    User.any_instance.unstub(:freshid_enabled_account?)
    Freshid::User.any_instance.unstub(:destroy)
  end

  def test_user_sync_from_freshid
    user = add_new_user(@account)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    freshid_user = Freshid::User.new(uuid: Faker::Number.number(10), first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, name: Faker::Name.name, email: Faker::Internet.email, password: Faker::Name.name)
    assert_equal user.sync_profile_from_freshid(freshid_user), true
    freshid_user_data = {
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name
    }
    assert_equal user.assign_freshid_attributes_to_contact(freshid_user_data), true
  ensure
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
  end

  def test_max_user_companies
    User.any_instance.stubs(:user_companies).returns(Array.new(301) { @account.companies.first })
    assert_not_nil @account.users.first.max_user_companies
  ensure
    User.any_instance.unstub(:user_companies)
  end

  def test_create_contact_raises_exception_on_save
    user = add_new_user(@account)
    error = ActiveRecord::RecordNotUnique.new('RecordNotUnique', 'Duplicate-Entry')
    User.any_instance.stubs(:save_without_session_maintenance).raises(error)
    assert_equal user.create_contact!(true), false
  ensure
    User.any_instance.unstub(:save_without_session_maintenance)
  end

  def test_create_contact_with_activation_email
    user = add_new_user(@account)
    Thread.stubs(:current).returns("notifications_#{@account.id}" => 1)
    User.any_instance.stubs(:save_without_session_maintenance).returns(true)
    user.create_contact!(true)
  ensure
    Thread.unstub(:current)
    User.any_instance.unstub(:save_without_session_maintenance)
  end

  def test_user_has_valid_freshid_password
    user = add_new_user(@account)
    Freshid::Login.any_instance.stubs(:authenticate_user).returns(true)
    Freshid::Login.any_instance.stubs(:valid_credentials?).returns(true)
    assert_equal user.valid_freshid_password?(Faker::Name.name), true
  ensure
    Freshid::Login.any_instance.unstub(:authenticate_user)
    Freshid::Login.any_instance.unstub(:valid_credentials?)
  end

  def test_user_signup
    ChargeBee::Customer.stubs(:update).returns(true)
    activation_params = {
      user: {
        name: Faker::Name.name
      }
    }
    user = add_new_user(@account)
    User.any_instance.stubs(:save_without_session_maintenance).returns(true)
    User.any_instance.stubs(:can_verify_account?).returns(true)
    assert_equal user.signup, true
    user.activate!(activation_params)
  ensure
    User.any_instance.unstub(:save_without_session_maintenance)
    User.any_instance.unstub(:can_verify_account?)
    ChargeBee::Customer.unstub(:update)
  end

  def test_user_name_with_only_unique_external_id
    user = User.new(unique_external_id: 1)
    User.any_instance.stubs(:scheduled_ticket_exports).returns([ScheduledTicketExport.new])
    ScheduledTicketExport.any_instance.stubs(:sync_to_service).returns(true)
    assert_equal user.safe_send(:has_role?), ['A user must be associated with atleast one role']
    user.sync_to_export_service
  ensure
    User.any_instance.unstub(:scheduled_ticket_exports)
    ScheduledTicketExport.any_instance.unstub(:sync_to_service)
  end

  def test_assign_company
    user = User.new
    User.any_instance.stubs(:privilege?).with(:manage_companies).returns(true)
    assert_equal user.name_details, ''
    assert_not_nil user.assign_company(Faker::Name.name)
    User.any_instance.stubs(:has_multiple_companies_feature?).returns(false)
    assert_equal user.assign_company('freshworks'), 'freshworks'
    assert_nil user.no_of_assigned_tickets('group')
    SBRR::QueueAggregator::User.any_instance.stubs(:relevant_queues).returns([SBRR::Queue::User.new(1, 1, 1)])
    SBRR::Queue::User.any_instance.stubs(:zscore).returns('1')
    assert_equal user.no_of_assigned_tickets('group'), 0
  ensure
    User.any_instance.unstub(:has_multiple_companies_feature?)
    User.any_instance.unstub(:privilege?)
    SBRR::QueueAggregator::User.any_instance.unstub(:relevant_queues)
    SBRR::Queue::User.any_instance.unstub(:zscore)
  end

  def test_update_attributes_with_tag_names
    update_params = {
      tags: 'Faker::Lorem.word'
    }
    user = User.new
    assert_equal user.update_attributes(update_params), false
  end

  def test_update_user_companies
    Account.any_instance.stubs(:skill_based_round_robin_enabled?).returns(true)
    User.any_instance.stubs(:skill_ids=).returns(true)
    new_company = create_company
    new_user = add_new_user(@account, customer_id: new_company.id)
    user_params = {
      user: {
        name: Faker::Name.name,
        phone: Faker::Number.number(10),
        mobile: Faker::Number.number(10),
        email: Faker::Internet.email,
        client_manager: false,
        removed_companies: ['test'].to_json,
        added_companies: [{ 'company_name' => 'test1', 'client_manager' => false, 'default_company' => true }].to_json,
        edited_companies: [{ 'id' => new_company.id, 'company_name' => 'test2', 'client_manager' => false, 'default_company' => true }].to_json,
        user_skills_attributes: [{ 'rank' => 1, 'skill_id' => 1 }]
      }
    }
    assert_includes new_user.build_user_attributes(user_params), 1
  ensure
    Account.any_instance.unstub(:skill_based_round_robin_enabled?)
    User.any_instance.unstub(:skill_ids=)
  end
end
