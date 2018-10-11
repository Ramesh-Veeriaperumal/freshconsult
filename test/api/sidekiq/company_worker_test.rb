require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'api', 'helpers', 'search_test_helper.rb')

class CompanyWorkerTest < ActionView::TestCase
  include SearchTestHelper

  def setup
    @account = Account.first.make_current
    @company = create_search_company(company_params_hash)
  end

  def company_params_hash
    name = Faker::Company.name
    description = Faker::Lorem.sentence
    domains = "#{Faker::Internet.domain_name},#{Faker::Internet.domain_name}"
    n = rand(10)
    params_hash = { name: name, description: description, domains: domains, custom_field: '', created_at: n.days.until.iso8601, updated_at: (n + 2).days.until.iso8601 }
    params_hash
  end

  def test_index
    args  = { csv_hash: { 'Company Name' => 'name', 'Description' => 'description', 'Notes' => 'note', 'Domains for this company' => 'domains', 'Health score' => 'health_score', 'Account tier' => 'account_tier', 'Renewal date' => 'renewal_date', 'Industry' => 'industry' },
              user: @account.users.first.id,
              portal_url: 'localhost.freshpo.com' }
    User.current = Account.current.users.first
    Export::Util.stubs(:build_attachment).returns(true)
    Export::CompanyWorker.new.perform(args)
    data_export = @account.data_exports.last
    assert_equal data_export.status, DataExport::EXPORT_STATUS[:completed]
    assert_equal data_export.source, DataExport::EXPORT_TYPE[:company]
    assert_equal data_export.last_error, nil
    data_export.destroy
    @company.destroy
  ensure
    Export::Util.unstub(:build_attachment)
  end
end
