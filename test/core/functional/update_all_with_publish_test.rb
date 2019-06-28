require_relative '../test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('spec', 'support', 'group_helper.rb')
require Rails.root.join('spec', 'support', 'ticket_helper.rb')

Sidekiq::Testing.fake!
class UpdateAllWithPublishTest < ActionView::TestCase
  include AccountTestHelper
  include CoreUsersTestHelper
  include GroupHelper
  include TicketHelper
  include BulkOperationsHelper

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.current
    @user = @account.nil? ? create_test_account : add_new_user(@account)
    @user.make_current
  end

  def create_n_tickets_with_group(count)
    group = create_group @account
    count.times do
      ticket = create_ticket(group)
      unless ticket.group_id
        ticket.group_id = group.id
        ticket.save!
      end
    end
    group
  end

  def test_update_all_with_publish_without_rate_limit_using_reset_group_worker
    group = create_n_tickets_with_group(6)
    jobs_count = Helpdesk::ResetGroup.jobs.count
    update_condition = { group_id: nil }
    options = { batch_size: 2, group_id: group.id, reason: { delete_group: group.id } }
    Account.current.tickets.where(group_id: group.id).update_all_with_publish(update_condition, {}, options)
    current_jobs_count = Helpdesk::ResetGroup.jobs.count
    assert jobs_count == current_jobs_count
  end

  def test_update_all_with_publish_with_rate_limit_using_reset_group_worker
    group = create_n_tickets_with_group(6)
    jobs_count = Helpdesk::ResetGroup.jobs.count
    update_condition = { group_id: nil }
    rate_limit_options = { batch_size: 2, run_after: 300, args: {}, class_name: 'Helpdesk::ResetGroup' }
    options = { batch_size: 2, group_id: group.id, reason: { delete_group: group.id }, rate_limit: rate_limit_options }
    Account.current.tickets.where(group_id: group.id).update_all_with_publish(update_condition, {}, options)
    current_jobs_count = Helpdesk::ResetGroup.jobs.count
    assert jobs_count == current_jobs_count - 1
  end
end
