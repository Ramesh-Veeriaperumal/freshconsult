require_relative '../../test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
['contact_fields_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['users_test_helper.rb', 'company_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['users_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
class ContactTest < ActiveSupport::TestCase
  include ContactFieldsHelper
  include CompanyTestHelper

  CUSTOM_FIELDS = %w[number checkbox decimal text paragraph dropdown country state city date].freeze
  DROPDOWN_CHOICES = ['Happy work environment', 'Team work', 'speak up'].freeze

  def setup
    super
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @account.subscription.state = 'active'
    @account.subscription.save
    @account.contact_form.contact_fields_from_cache
  end

  def test_contact_publish_with_launch_party_enabled
    CentralPublishWorker::UserWorker.jobs.clear
    add_new_user(@account)
    assert_equal 1, CentralPublishWorker::UserWorker.jobs.size
  end

  def test_central_publish_payload
    create_contact_field(cf_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Metropolitian City', editable_in_signup: 'true'))
    user = add_new_user(@account, customer_id: create_company.reload.id)
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(contact_pattern(user))
  end

  def test_central_pulblish_contact_update
    user = add_new_user(@account)
    old_name = user.name
    CentralPublishWorker::UserWorker.jobs.clear
    user.reload
    user.update_attributes(name: 'new name')
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(contact_pattern(user))
    assert_equal 1, CentralPublishWorker::UserWorker.jobs.size
    job = CentralPublishWorker::UserWorker.jobs.last
    assert_equal 'contact_update', job['args'][0]
    assert_equal({ 'name' => [old_name, user.name] }, job['args'][1]['model_changes'])
  end

  def test_central_pulblish_contact_update_cf
    contact_field = create_contact_field(cf_params(type: 'boolean',
                                                   field_type: 'custom_checkbox',
                                                   label: 'city',
                                                   editable_in_signup: 'true'))
    column_name = contact_field.name
    user = add_new_user(@account)
    CentralPublishWorker::UserWorker.jobs.clear
    user.reload
    user.update_attributes(custom_field: { cf_city: true })
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(contact_pattern(user))
    assert_equal 1, CentralPublishWorker::UserWorker.jobs.size
    job = CentralPublishWorker::UserWorker.jobs.last
    assert_equal 'contact_update', job['args'][0]
    assert_equal({ column_name => [nil, true] }, job['args'][1]['model_changes'])
  end

  def contact_pattern(contact, expected_output = {})
    result = {
      active: expected_output[:active] || contact.active,
      address: expected_output[:address] || contact.address,
      customer_id: expected_output[:customer_id] || contact.customer_id,
      description: expected_output[:description] || contact.description,
      email: expected_output[:email] || contact.email,
      id: contact.id,
      job_title: expected_output[:job_title] || contact.job_title,
      language: expected_output[:language] || contact.language,
      mobile: expected_output[:mobile] || contact.mobile,
      name: expected_output[:name] || contact.name,
      phone: expected_output[:phone] || contact.phone,
      time_zone: expected_output[:time_zone] || contact.time_zone,
      twitter_id: expected_output[:twitter_id] || contact.twitter_id,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      custom_fields: contact.custom_field_hash('contact') || contact.custom_field.map { |k, v| [CustomFieldDecorator.display_name(k), v.respond_to?(:utc) ? v.strftime('%F') : v] }.to_h,
      fb_profile_id: expected_output[:fb_profile_id] || contact.fb_profile_id,
      unique_external_id: contact.unique_external_id,
      last_login_ip: contact.last_login_ip,
      current_login_ip: contact.current_login_ip,
      privileges: contact.privileges,
      blocked: contact.blocked,
      helpdesk_agent: contact.helpdesk_agent,
      delta: contact.delta,
      type: contact.agent_or_contact,
      import_id:  contact.import_id,
      extn: contact.extn,
      parent_id: contact.parent_id,
      last_seen_at: contact.last_seen_at,
      blocked_at: contact.blocked_at,
      deleted_at: contact.deleted_at,
      whitelisted: contact.whitelisted,
      current_login_at: contact.current_login_at,
      last_login_at: contact.last_login_at,
      failed_login_count: contact.failed_login_count,
      login_count: contact.login_count,
      account_id: contact.account_id,
      second_email: contact.second_email,
      posts_count: contact.posts_count,
      deleted: contact.deleted,
      user_role: contact.user_role,
      external_id: contact.external_id,
      preferences: contact.preferences 
    }
    result
  end

  def get_company_id(contact)
    default_company = get_default_company(contact)
    default_company ? default_company.company_id : nil
  end

  def get_default_company(contact)
    contact.user_companies.find_by_default(true)
  end
end
