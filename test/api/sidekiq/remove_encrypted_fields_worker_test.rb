require_relative '../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
['contact_fields_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')

class ResetAssociationsTest < ActionView::TestCase
  include ApiTicketsTestHelper
  include ContactFieldsHelper
  include Cache::Memcache::CompanyField
  include Cache::Memcache::ContactField

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_removing_encrypted_fields
    create_encrypted_fields
    # assert_equal @account.ticket_fields.encrypted_custom_fields.length, 1
    assert_equal @account.contact_form.encrypted_custom_contact_fields.length, 1
    assert_equal @account.company_form.encrypted_custom_company_fields.length, 1
    RemoveEncryptedFieldsWorker.new.perform
    @account.reload
    # assert_equal @account.ticket_fields.encrypted_custom_fields.length, 0
    assert_equal @account.contact_form.encrypted_custom_contact_fields.length, 0
    assert_equal @account.company_form.encrypted_custom_company_fields.length, 0
  end

  private

  def create_encrypted_fields
    # create_custom_field(Faker::Name.name, "encrypted_text")
    create_contact_field(cf_params(type: 'encrypted_text', field_type: 'encrypted_text', label: Faker::Name.name, editable_in_signup: 'false'))
    create_company_field(company_params(type: 'encrypted_text', field_type: 'encrypted_text', label: Faker::Name.name))
    clear_contact_fields_cache
    clear_company_fields_cache
  end
end