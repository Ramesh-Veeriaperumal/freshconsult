require_relative '../test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('spec', 'support', 'ticket_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'tag_test_helper.rb')

Sidekiq::Testing.fake!
class FindInBatchesWithRatelimitTest < ActionView::TestCase
  include AccountTestHelper
  include CoreUsersTestHelper
  include TicketHelper
  include TagTestHelper

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.current
    @user = @account.nil? ? create_test_account : add_new_user(@account)
    @user.make_current
  end

  def create_n_tickets_with_tag(count)
    tag = create_tag @account
    count.times do
      ticket = create_ticket
      ticket.tag_names = tag.name
    end
    tag
  end

  def test_find_in_batches_with_rate_limit_using_search_v2_index_perations
    tag = create_n_tickets_with_tag(10)
    jobs_count = SearchV2::IndexOperations::UpdateTaggables.jobs.count
    rate_limit_options = { batch_size: 6, run_after: 300, args: {}, class_name: 'SearchV2::IndexOperations::UpdateTaggables' }
    options = { batch_size: 3, rate_limit: rate_limit_options }
    tag.tag_uses.preload(:taggable).find_in_batches_with_rate_limit(options) do |taguses|
      puts 'doing nothing'
    end
    current_jobs_count = SearchV2::IndexOperations::UpdateTaggables.jobs.count
    assert jobs_count == current_jobs_count - 1
  end
end
