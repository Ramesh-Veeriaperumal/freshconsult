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
    WebMock.allow_net_connect!
  end

  def teardown
    @company.destroy
    WebMock.disable_net_connect!
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
    export_entry = @account.data_exports.new(
                            :source => DataExport::EXPORT_TYPE["company".to_sym], 
                            :user => User.current,
                            :status => DataExport::EXPORT_STATUS[:started]
                            )
    export_entry.save
    hash = Digest::SHA1.hexdigest("#{export_entry.id}#{Time.now.to_f}")
    export_entry.save_hash!(hash)
    args  = { csv_hash: { 'Company Name' => 'name', 'Description' => 'description', 'Notes' => 'note', 'Domains for this company' => 'domains', 'Health score' => 'health_score', 'Account tier' => 'account_tier', 'Renewal date' => 'renewal_date', 'Industry' => 'industry' },
              user: @account.users.first.id,
              portal_url: 'localhost.freshpo.com', data_export: export_entry.id }
    User.current = Account.current.users.first
    Export::CompanyWorker.new.perform(args)
    export_entry.reload
    assert_equal export_entry.status, DataExport::EXPORT_STATUS[:completed]
    assert_equal export_entry.source, DataExport::EXPORT_TYPE[:company]
    assert_equal export_entry.last_error, nil
  ensure
    export_entry.destroy
  end
end
