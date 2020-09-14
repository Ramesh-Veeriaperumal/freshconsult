require_relative '../unit_test_helper'
require_relative '../../lib/helpers/contact_segments_test_helper.rb'
require 'sidekiq/testing'
require 'faker'
['tickets_test_helper.rb', 'users_test_helper.rb', 'account_test_helper.rb', 'note_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

Sidekiq::Testing.fake!

class MergeContactsTest < ActionView::TestCase
  include ContactSegmentsTestHelper
  include CoreTicketsTestHelper
  include CoreUsersTestHelper
  include NoteTestHelper

  def setup
    super
    @account = Account.first || create_test_account
    Account.stubs(:current).returns(Account.first)
    MergeContacts.jobs.clear
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def create_child_contact(parent_contact_id)
    child = create_contact
    child.string_uc04 = parent_contact_id
    child.save
    child.id
  end

  def construct_args
    parent_id = create_contact.id
    child_id = create_child_contact(parent_id)
    { 'parent': parent_id,
      'children': [child_id] }
  end

  def test_merge_contacts_worker_runs
    args = construct_args.stringify_keys!
    MergeContacts.new.perform(args)
    assert_equal 0, MergeContacts.jobs.size
  end

  def test_merge_contacts_worker_errors_out
    args = construct_args.stringify_keys!
    Account.any_instance.stubs(:contacts).raises(Exception.new('exception test'))
    MergeContacts.new.perform(args)
    assert_equal 0, MergeContacts.jobs.size
  end

  def test_merge_contacts_with_archive_tickets
    args = construct_args.stringify_keys!
    Account.any_instance.stubs(:features_included?).returns(true)
    MergeContacts.new.perform(args)
    assert_equal 0, MergeContacts.jobs.size
  end

  def test_merge_contacts_with_parent_contractor
    args = construct_args.stringify_keys!
    User.any_instance.stubs(:contractor?).returns(true)
    MergeContacts.new.perform(args)
    assert_equal 0, MergeContacts.jobs.size
  end

  def test_merge_contacts_with_parent_contractor_and_archive_tickets
    args = construct_args.stringify_keys!
    User.any_instance.stubs(:contractor?).returns(true)
    Account.any_instance.stubs(:features_included?).returns(true)
    MergeContacts.new.perform(args)
    assert_equal 0, MergeContacts.jobs.size
  end

  def test_merge_contacts_with_mobile_att
    args = construct_args.stringify_keys!
    ContactForm.any_instance.stubs(:custom_contact_fields).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:map).returns(['mobile'])
    MergeContacts.new.perform(args)
    assert_equal 0, MergeContacts.jobs.size
  end

  def test_merge_contacts_with_ticket_and_note_central_event
    parent_contact = create_contact
    child_contact = create_contact
    ticket = create_ticket(requester_id: child_contact.id)
    note = create_note(user_id: child_contact.id, incoming: 1, private: false, ticket_id: ticket.id, source: 0, body: 'Lets meet at 5pm today', body_html: '<div>Lets meet at 5pm today</div>')
    child_contact.string_uc04 = parent_contact.id
    child_contact.save
    args = { 'parent': parent_contact.id, 'children': [child_contact.id] }
    UpdateAllPublisher.jobs.clear
    MergeContacts.new.perform(args.stringify_keys!)
    assert_equal 2, UpdateAllPublisher.jobs.size
    ticket_payload = UpdateAllPublisher.jobs.find { |job| job['args'][0]['klass_name'].eql? ticket.class.name }
    ticket_payload['args'][0].to_json.must_match_json_expression(central_payload_data(ticket))
    note_payload = UpdateAllPublisher.jobs.find { |job| job['args'][0]['klass_name'].eql? note.class.name }
    note_payload['args'][0].to_json.must_match_json_expression(central_payload_data(note))
  ensure
    UpdateAllPublisher.jobs.clear
    note.destroy
    ticket.destroy
    child_contact.destroy
    parent_contact.destroy
  end

  private

    def central_payload_data(data)
      res_hash = {
        klass_name: data.class.name,
        ids: Array,
        updates: Hash,
        options: { manual_publish: true }
      }
      res_hash
    end
end
