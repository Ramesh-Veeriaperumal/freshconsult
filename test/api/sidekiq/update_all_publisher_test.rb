# frozen_string_literal: true

require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
['tickets_test_helper.rb', 'users_test_helper.rb', 'account_test_helper.rb', 'note_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['contact_segments_test_helper.rb'].each { |file| require "#{Rails.root}/test/lib/helpers/#{file}" }
Sidekiq::Testing.fake!

class UpdateAllPublisherTest < ActionView::TestCase
  include ContactSegmentsTestHelper
  include CoreTicketsTestHelper
  include CoreUsersTestHelper
  include NoteTestHelper

  def setup
    super
    @account = Account.first || create_test_account
    @account.make_current
    UpdateAllPublisher.jobs.clear
  end

  def test_update_all_publisher_worker_with_ticket
    ticket = create_ticket
    new_user = add_new_user(@account)
    ticket.attributes = { requester_id: new_user.id }
    ticket.save
    options = { manual_publish: true, model_changes: { requester_id: new_user.id } }
    CentralPublisher::DelayedPublishWorker.jobs.clear
    UpdateAllPublisher.new.perform(klass_name: 'Helpdesk::Ticket', ids: [ticket.id], options: options)
    assert_equal 1, CentralPublisher::DelayedPublishWorker.jobs.size
  ensure
    ticket.destroy
    new_user.destroy
  end
end
