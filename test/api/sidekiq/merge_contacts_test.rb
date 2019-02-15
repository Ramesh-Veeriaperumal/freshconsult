require_relative '../unit_test_helper'
require_relative '../../lib/helpers/contact_segments_test_helper.rb'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

class MergeContactsTest < ActionView::TestCase
  include ContactSegmentsTestHelper

  def setup
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
end
