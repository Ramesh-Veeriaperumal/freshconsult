require_relative '../unit_test_helper'
require_relative '../../test_transactions_fixtures_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class ContactEnrichmentTest < ActionView::TestCase
  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def teardown
    Account.unstub(:current)
  end

  def test_contact_enrichment
    args = { 'email_update' => User.first.email }
    result = Clearbit::Enrichment.find(email: @account.contact_info[:email], stream: true)
    value = ContactEnrichment.new.perform(args)
    response = { :name  => result.company.name, :phone_numbers => result.company.site.phoneNumbers, :industry => result.company.category.industry, 
    :tags => result.company.tags, :location => result.company.geo, :twitter => result.company.twitter.handle, :facebook => result.company.facebook.handle,
    :crunchbase => result.company.crunchbase.handle, :logo => result.company.logo, :metrics => result.company.metrics }
    assert_equal value, true
    assert_equal @account.account_configuration.company_info, response
  end

  def test_contact_enrichment_without_arguments
    assert_nothing_raised do
      args = {}
      ContactEnrichment.any_instance.stubs(:generate_clearbit_contact_info).raises(StandardError)
      ContactEnrichment.new.perform(args)
    end
  ensure
    ContactEnrichment.unstub(:generate_clearbit_contact_info)
  end

  def test_contact_enrichment_without_email_update
    assert_nothing_raised do
      args = { 'email_update' => nil }
      @account.contact_info[:email] = ' '
      ContactEnrichment.new.perform(args)
    end
  end
end

