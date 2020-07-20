require_relative '../../test_helper'
['canned_responses_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class Admin::CannedResponses::FolderTest < ActiveSupport::TestCase
  include CannedResponsesHelper
  def test_to_create_duplicate_canned_response_folder
    name = SecureRandom.uuid
    cr_folder = create_cr_folder(name: name)
    cr_folder.save!
    another_cr_folder = create_cr_folder(name: name)
    another_cr_folder.save
    assert_equal true, another_cr_folder.errors.any?
    assert_equal ['has already been taken'], another_cr_folder.errors.messages[:name]
  ensure
    cr_folder.destroy
  end

  def test_to_create_canned_response_folder_with_previously_deleted_folder_name
    name = SecureRandom.uuid
    cr_folder = create_cr_folder(name: name)
    cr_folder.deleted = true
    cr_folder.save!
    another_cr_folder = create_cr_folder(name: name)
    another_cr_folder.save!
    assert_equal false, another_cr_folder.errors.any?
    assert_equal Admin::CannedResponses::Folder.order('id asc').last, another_cr_folder
  ensure
    cr_folder.destroy
    another_cr_folder.destroy
  end

  def test_to_soft_delete_a_folder_with_name_that_previously_existed
    name = SecureRandom.uuid
    cr_folder = create_cr_folder(name: name)
    cr_folder.deleted = true
    cr_folder.save!
    another_cr_folder = create_cr_folder(name: name)
    another_cr_folder.deleted = true
    another_cr_folder.save!
    assert_equal false, another_cr_folder.errors.any?
    assert_equal Admin::CannedResponses::Folder.order('id asc').last, another_cr_folder
  ensure
    cr_folder.destroy
    another_cr_folder.destroy
  end
end
