require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'api', 'helpers', 'search_test_helper.rb')

class CompanyWorkerTest < ActionView::TestCase
  include SearchTestHelper

  def setup
    @account = Account.first.make_current
    @contact = create_search_contact(contact_params_hash)
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
    args = { csv_hash: { 'Full name' => 'name', 'Title' => 'job_title', 'Email' => 'email', 'Work phone' => 'phone', 'Mobile phone' => 'mobile', 'Twitter' => 'twitter_id', 'Company' => 'company_name', 'Address' => 'address', 'Time zone' => 'time_zone', 'Language' => 'language', 'About' => 'description', 'Can see all tickets from this company' => 'client_manager', 'Unique external ID' => 'unique_external_id' },
             user: @account.users.first.id,
             portal_url: 'localhost.freshpo.com' }
    User.current = Account.current.users.first
    Export::Util.stubs(:build_attachment).returns(true)
    Export::ContactWorker.new.perform(args)
    data_export = @account.data_exports.last
    assert_equal data_export.status, DataExport::EXPORT_STATUS[:completed]
    assert_equal data_export.source, DataExport::EXPORT_TYPE[:contact]
    assert_equal data_export.last_error, nil
    data_export.destroy
    @contact.destroy
  ensure
    Export::Util.unstub(:build_attachment)
  end
end
