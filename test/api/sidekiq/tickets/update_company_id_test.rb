require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')

Sidekiq::Testing.fake!

class UpdateCompanyIdTest < ActionView::TestCase

  include AccountTestHelper
  include TicketsTestHelper

  def setup
    @account = Account.first.make_current
    ::Tickets::UpdateCompanyId.jobs.clear
  end

  def construct_args(user_id, company_id)
    {
      user_ids: user_id,
      company_id: company_id
    }
  end

  def create_company(options = {})
    company = @account.companies.find_by_name(options[:name])
    return company if company
    name = options[:name] || Faker::Name.name
    company = FactoryGirl.build(:company, name: name)
    company.account_id = @account.id
    company.save!
    company
  end

  def test_update_company_id_worker_runs
    user = create_dummy_customer
    company = create_company
    args = construct_args(user.id, company.id)
    ::Tickets::UpdateCompanyId.new.perform(args)
    assert_equal 0, ::Tickets::UpdateCompanyId.jobs.size
  end

  def test_update_company_id_worker_with_tickets
    user = create_dummy_customer
    company = create_company
    ticket = create_ticket(requester_id: user.id)
    args = construct_args(user.id, company.id)
    ::Tickets::UpdateCompanyId.new.perform(args)
    assert_equal 0, ::Tickets::UpdateCompanyId.jobs.size
  end
end
