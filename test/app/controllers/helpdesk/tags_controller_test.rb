require_relative '../../../api/test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'tag_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'tag_use_test_helper.rb')

module Helpdesk
  class TagsControllerTest < ActionController::TestCase
    include AccountTestHelper
    include CreateTicketHelper
    include TagTestHelper
    include TagUseTestHelper

    def setup
      super
      @account = Account.first || create_test_account
    end

    def test_remove_tag_use
      Helpdesk::Ticket.any_instance.stubs(:manual_publish).returns(nil)
      ticket = create_test_ticket(email: 'sample@freshdesk.com')
      tag_use = create_tag_use(@account, taggable_type: 'Helpdesk::Ticket', taggable_id: ticket.id, allow_skip: true)
      tag = tag_use.tags
      tag_use_job_size = TagUsesCleaner.jobs.size
      update_all_job_size = UpdateAllPublisher.jobs.size
      delete :remove_tag, tag_id: tag.id, tag_type: 'Helpdesk::Ticket'
      assert_response 200
      tag_uses_count = Account.current.tag_uses.where(tag_id: tag.id, taggable_type: 'Helpdesk::Ticket').count
      match_json(tag_uses_removed_count: tag_uses_count)
      assert_equal true, TagUsesCleaner.jobs.size == tag_use_job_size + 1
      tag_use_job = TagUsesCleaner.jobs.last
      assert_equal User.current.id, tag_use_job['args'][0]['doer_id']
      assert_equal tag.id.to_s, tag_use_job['args'][0]['tag_id']
      assert_equal 'Helpdesk::Ticket', tag_use_job['args'][0]['taggable_type']
      TagUsesCleaner.new.perform(tag_use_job['args'][0])
      assert_equal true, UpdateAllPublisher.jobs.size == update_all_job_size + 1
      update_all_job = UpdateAllPublisher.jobs.last
      assert_equal 'Helpdesk::Ticket', update_all_job['args'][0]['klass_name']
      assert_equal '1.*.*.*.1.#', update_all_job['args'][0]['options']['routing_key']
      assert_equal({ 'tags' => { 'added' => [], 'removed' => [tag.name] } }, update_all_job['args'][0]['options']['model_changes'])
      assert_equal tag_use_job['args'][0][:doer_id], update_all_job['args'][0]['options']['doer_id']
      assert_equal [ticket.id], update_all_job['args'][0]['ids']
      UpdateAllPublisher.new.perform(update_all_job['args'][0])
    ensure
      Helpdesk::Ticket.any_instance.unstub(:manual_publish)
    end

    def test_remove_tag
      Helpdesk::Ticket.any_instance.stubs(:manual_publish).returns(nil)
      ticket = create_test_ticket(email: 'sample@freshdesk.com')
      tag_use = create_tag_use(@account, taggable_type: 'Helpdesk::Ticket', taggable_id: ticket.id, allow_skip: true)
      tag = tag_use.tags
      tag_use_job_size = TagUsesCleaner.jobs.size
      update_all_job_size = UpdateAllPublisher.jobs.size
      post :destroy, id: 'delete', ids: ["#{tag.id}-#{tag.name}"], '_method': 'delete'
      assert_response :redirect
      assert response.header['Location'], 'http://localhost.freshpo.com/helpdesk/tags'
      assert_equal true, TagUsesCleaner.jobs.size == tag_use_job_size + 1
      tag_use_job = TagUsesCleaner.jobs.last
      assert_equal User.current.id, tag_use_job['args'][0]['doer_id']
      assert_equal tag.id, tag_use_job['args'][0]['tag_id']
      TagUsesCleaner.new.perform(tag_use_job['args'][0])
      assert_equal true, UpdateAllPublisher.jobs.size == update_all_job_size + 1
      update_all_job = UpdateAllPublisher.jobs.last
      assert_equal 'Helpdesk::Ticket', update_all_job['args'][0]['klass_name']
      assert_equal '1.*.*.*.1.#', update_all_job['args'][0]['options']['routing_key']
      assert_equal({ 'tags' => { 'added' => [], 'removed' => [tag.name] } }, update_all_job['args'][0]['options']['model_changes'])
      assert_equal tag_use_job['args'][0][:doer_id], update_all_job['args'][0]['options']['doer_id']
      assert_equal [ticket.id], update_all_job['args'][0]['ids']
      UpdateAllPublisher.new.perform(update_all_job['args'][0])
    ensure
      Helpdesk::Ticket.any_instance.unstub(:manual_publish)
    end
  end
end
