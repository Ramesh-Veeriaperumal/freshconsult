require_relative '../test_helper'
require 'faker'
require Rails.root.join('spec', 'support', 'user_helper.rb')
['contact_fields_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class UserTest < ActiveSupport::TestCase
  include UsersHelper
  include ContactFieldsHelper

  def setup
    super
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @account.subscription.state = 'active'
    @account.subscription.save
    @account.contact_form.contact_fields_from_cache
  end

  def teardown
    Account.unstub(:current)
  end

  def test_central_publish_payload
    user = add_new_user(@account)
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_user_pattern(user))
  end

  def test_user_update_without_feature
    @account.rollback(:audit_logs_central_publish)
    CentralPublishWorker::UserWorker.jobs.clear
    update_user
    assert_equal 0, CentralPublishWorker::UserWorker.jobs.size
  ensure
    @account.launch(:audit_logs_central_publish)
  end

  def test_user_update_with_feature
    CentralPublishWorker::UserWorker.jobs.clear
    update_user
    assert_equal 1, CentralPublishWorker::UserWorker.jobs.size
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
end
