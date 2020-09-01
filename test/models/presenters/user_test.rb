require_relative '../test_helper'
require 'faker'
['contact_fields_helper.rb','company_helper.rb', 'user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class UserTest < ActiveSupport::TestCase
  include UsersHelper
  include ContactFieldsHelper
  include CompanyHelper

  def setup
    super
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @account.subscription.state = 'active'
    @account.subscription.save
    @account.contact_form.contact_fields_from_cache
  end

  def teardown
    CentralPublishWorker::UserWorker.jobs.clear
    Account.unstub(:current)
  end

  def test_central_publish_payload
    user = add_new_user(@account)
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_user_pattern(user))
  end

  def test_user_update_with_feature
    CentralPublishWorker::UserWorker.jobs.clear
    update_user
    assert_equal 0, CentralPublishWorker::UserWorker.jobs.size
    user = Account.current.technicians.first
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_user_pattern(user))
  end

  def test_create_cf_central_publish_payload
    create_contact_field(cf_params(type: 'boolean', 
                                   field_type: 'custom_checkbox', 
                                   label: 'Metropolitian City', 
                                   editable_in_signup: 'true'))
    user = add_new_user(@account)
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_user_pattern(user))
  end

  def test_create_cf_dropdown_central_publish_payload
    choices = [{ value: Faker::Lorem.characters(10), position: 1 }, { value: Faker::Lorem.characters(10), position: 2 }]
    create_contact_field(cf_params(type: 'dropdown',
                                   field_type: 'custom_dropdown',
                                   label: Faker::Lorem.characters(10),
                                   editable_in_signup: 'true',
                                   custom_field_choices_attributes: choices))
    user = add_new_user(@account)
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_user_pattern(user))
  end

  def test_update_cf_central_publish_payload
    label = Faker::Lorem.characters(10)
    contact_field = create_contact_field(cf_params(type: 'boolean',
                                                   field_type: 'custom_checkbox',
                                                   label: label,
                                                   editable_in_signup: 'true'))
    column_name = contact_field.name
    user = add_new_user(@account)
    CentralPublishWorker::UserWorker.jobs.clear
    user.reload
    user.update_attributes(custom_field: { "cf_#{label}": true })
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_user_pattern(user))
    assert_equal 1, CentralPublishWorker::UserWorker.jobs.size
    job = CentralPublishWorker::UserWorker.jobs.last
    assert_equal 'contact_update', job['args'][0]
    assert_equal({ column_name => [nil, true] }, job['args'][1]['model_changes'])
  end

  def test_update_cf_dropdown_central_publish_payload
    label = Faker::Lorem.characters(10)
    choices = [{ value: Faker::Lorem.characters(10), position: 1 }, { value: Faker::Lorem.characters(10), position: 2 }]
    create_contact_field(cf_params(type: 'dropdown',
                                   field_type: 'custom_dropdown',
                                   label: label,
                                   editable_in_signup: 'true',
                                   custom_field_choices_attributes: choices))
    user = add_new_user(@account)
    CentralPublishWorker::UserWorker.jobs.clear
    user.reload
    user.update_attributes(custom_field: { "cf_#{label}": choices.last[:value] })
    assert_equal 1, CentralPublishWorker::UserWorker.jobs.size
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_user_pattern(user))
  end

  def test_cf_dropdown_with_null_choice_id
    label = Faker::Lorem.characters(10)
    choices = [{ value: Faker::Lorem.characters(10), position: 1 }, { value: Faker::Lorem.characters(10), position: 2 }]
    create_contact_field(cf_params(type: 'dropdown',
                                   field_type: 'custom_dropdown',
                                   label: label,
                                   editable_in_signup: 'true',
                                   custom_field_choices_attributes: choices))
    user = add_new_user(@account)
    CentralPublishWorker::UserWorker.jobs.clear
    user.reload
    User.any_instance.stubs(:fetch_choice_id).returns(nil)
    user.update_attributes(custom_field: { "cf_#{label}": choices.last[:value] })
    assert_equal 1, CentralPublishWorker::UserWorker.jobs.size
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_user_pattern(user))
  ensure
    User.any_instance.unstub(:fetch_choice_id)
  end

  def test_central_publish_user_other_emails
    user = add_new_user(@account)
    user.user_emails.build(email: Faker::Internet.email, primary_role: false)
    user.save
    user.reload
    payload_json = user.central_publish_payload.to_json
    payload_json.must_match_json_expression(central_publish_user_pattern(user))
  end

  def test_central_publish_user_tags
    new_tag = [Faker::Lorem.characters(10)]
    user = add_new_user(@account, tags: new_tag)
    payload_json = user.central_publish_payload.to_json
    payload_json.must_match_json_expression(central_publish_user_pattern(user))
  end

  def test_central_publish_model_changes_user_other_emails
    user = add_new_user(@account)
    other_email = user.user_emails.build(email: Faker::Internet.email, primary_role: false)
    payload = other_email.construct_model_changes
    assert_equal payload[:other_emails][:added], [other_email.email]
    user.save
    user.reload
    other_email.destroy
    changes = other_email.override_exchange_model(:destroy)
    assert_equal changes[:other_emails][:removed], [other_email.email]
  end

  def test_central_publish_model_changes_user_tags
    new_tags = [Faker::Lorem.characters(10), Faker::Lorem.characters(10)]
    user = add_new_user(@account, tags: new_tags)
    assert_equal user.model_changes_for_central[:tags][:added_tags].include?(new_tags[0]), true
    assert_equal user.model_changes_for_central[:tags][:added_tags].include?(new_tags[1]), true
    user.save
    user.save_tags
    tag = Helpdesk::Tag.where(name: new_tags[0]).first
    tag.delete
    assert_equal user.model_changes_for_central[:tags][:removed_tags].first, new_tags[0]
  end

  def test_central_publish_model_changes_user_companies
    # add default company
    company = create_company
    user = add_new_user(@account)
    default_user_company = Account.current.user_companies.build(user_id: user.id, company_id: company.id, client_manager: false, default: true)
    CentralPublishWorker::UserWorker.jobs.clear
    default_user_company.save
    assert_equal 1, CentralPublishWorker::UserWorker.jobs.size
    job = CentralPublishWorker::UserWorker.jobs.last
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_user_pattern(user))
    assert_equal 'contact_update', job['args'][0]
    assert_includes job['args'][0], job['args'][1]['event']
    assert_equal [nil, company.id], job['args'][1]['model_changes']['company_id']
    assert_equal true, job['args'][1]['event_info']['app_update']

    # add other user_companies
    company = create_company
    other_user_company = Account.current.user_companies.build(user_id: user.id, company_id: company.id, client_manager: false, default: false)
    CentralPublishWorker::UserWorker.jobs.clear
    other_user_company.save
    assert_equal 1, CentralPublishWorker::UserWorker.jobs.size
    job = CentralPublishWorker::UserWorker.jobs.last
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_user_pattern(user))
    assert_equal 'contact_update', job['args'][0]
    assert_includes job['args'][0], job['args'][1]['event']
    assert_equal [company.id], job['args'][1]['model_changes']['other_company_ids']['added']

    # remove default company
    CentralPublishWorker::UserWorker.jobs.clear
    deleted_company_id = default_user_company.id
    p "deleted_company_id :: #{deleted_company_id} :: #{default_user_company.inspect}"
    default_user_company.destroy
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_user_pattern(user))

    assert_equal 3, CentralPublishWorker::UserWorker.jobs.size
    CentralPublishWorker::UserWorker.jobs.each do |central_job|
      company_id_changes = central_job['args'][1]['model_changes']['company_id']
      customer_id_changes = central_job['args'][1]['model_changes']['customer_id']
      assert_equal 'contact_update', central_job['args'][0]
      assert_includes job['args'][0], central_job['args'][1]['event']
      if company_id_changes.present? && company_id_changes[1].nil?
        assert_equal [default_user_company.company_id, nil], central_job['args'][1]['model_changes']['company_id']
      elsif company_id_changes.present? && company_id_changes[0].nil? # other company to default company
        assert_equal [nil, other_user_company.company_id], central_job['args'][1]['model_changes']['company_id']
        assert_equal [other_user_company.company_id], central_job['args'][1]['model_changes']['other_company_ids']['removed']
      elsif customer_id_changes.present?
        assert_equal [nil, other_user_company.company_id], central_job['args'][1]['model_changes']['customer_id']
      end
    end

    CentralPublishWorker::UserWorker.jobs.clear
  end

  def test_central_publish_payload_event_info_marketplace_attribute_for_custom_field_update
    label = Faker::Lorem.characters(10)
    choices = [{ value: Faker::Lorem.characters(10), position: 1 }, { value: Faker::Lorem.characters(10), position: 2 }]
    custom_field = create_contact_field(cf_params(type: 'dropdown', field_type: 'custom_dropdown', label: label, editable_in_signup: 'true', custom_field_choices_attributes: choices))
    user = add_new_user(@account)
    user.save
    user.update_attributes(custom_field: { custom_field.name => choices.sample })
    event_info = user.event_info(:update)
    event_info.must_match_json_expression(cp_user_event_info_pattern(app_update: true))
  end

  def test_central_publish_payload_event_info_marketplace_attribute_for_user_emails_updated
    user = add_new_user(@account)
    user.user_emails.build(email: Faker::Internet.email, primary_role: false)
    user.save
    event_info = user.event_info(:update)
    event_info.must_match_json_expression(cp_user_event_info_pattern(app_update: true))
  end

  def test_central_publish_payload_event_info_marketplace_attribute_for_tags_updated
    new_tags = [Faker::Lorem.characters(10), Faker::Lorem.characters(10)]
    user = add_new_user(@account, tags: new_tags)
    user.save
    user.save_tags
    event_info = user.event_info(:update)
    event_info.must_match_json_expression(cp_user_event_info_pattern(app_update: true))
  end

  def test_central_publish_payload_event_info_marketplace_attribute_with_invalid_attribute_updated
    user = add_new_user(@account)
    user.update_attributes(login_count: 2)
    event_info = user.event_info(:update)
    event_info.must_match_json_expression(cp_user_event_info_pattern(app_update: false))
  end

  def test_central_publish_payload_event_info_marketplace_attribute_with_valid_marketplace_attribute
    user = add_new_user(@account)
    user.save
    user.update_attributes(description: Faker::Lorem.characters(10))
    event_info = user.event_info(:update)
    event_info.must_match_json_expression(cp_user_event_info_pattern(app_update: true))
  end
end
