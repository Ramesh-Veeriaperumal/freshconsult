require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'api', 'helpers', 'search_test_helper.rb')

class ContactWorkerTest < ActionView::TestCase
  include SearchTestHelper

  def setup
    @account = Account.first.make_current
    @contact = create_search_contact(contact_params_hash)
  end

  def teardown
    @contact.destroy
  end

  def contact_params_hash
    email = Faker::Internet.email
    twitter_id = Faker::Internet.user_name
    mobile = Faker::Number.number(10)
    phone = Faker::Number.number(10)
    n = rand(10)
    params_hash = { email: email, twitter_id: twitter_id, customer_id: '', mobile: mobile, phone: phone, language: ContactConstants::LANGUAGES[n],
                    time_zone: ContactConstants::TIMEZONES[n], custom_field: '', created_at: n.days.until.iso8601, updated_at: (n + 2).days.until.iso8601, active: true }
    params_hash
  end

  def test_index
    export_entry = @account.data_exports.new(
                            :source => DataExport::EXPORT_TYPE["contact".to_sym], 
                            :user => User.current,
                            :status => DataExport::EXPORT_STATUS[:started]
                            )
    export_entry.save
    hash = Digest::SHA1.hexdigest("#{export_entry.id}#{Time.now.to_f}")
    export_entry.save_hash!(hash)
    args = { csv_hash: { 'Full name' => 'name', 'Title' => 'job_title', 'Email' => 'email', 'Work phone' => 'phone', 'Mobile phone' => 'mobile', 'Twitter' => 'twitter_id', 'Company' => 'company_name', 'Address' => 'address', 'Time zone' => 'time_zone', 'Language' => 'language', 'About' => 'description', 'Can see all tickets from this company' => 'client_manager', 'Unique external ID' => 'unique_external_id' },
             user: @account.users.first.id,
             portal_url: 'localhost.freshpo.com', data_export: export_entry.id }
    User.current = Account.current.users.first
    Export::ContactWorker.new.perform(args)
    export_entry.reload
    assert_equal export_entry.status, DataExport::EXPORT_STATUS[:completed]
    assert_equal export_entry.source, DataExport::EXPORT_TYPE[:contact]
    assert_equal export_entry.last_error, nil
  ensure
    export_entry.destroy
  end
end
