require_relative '../unit_test_helper'
require_relative '../helpers/attachments_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

class ProductFeedbackWorkerTest < ActionView::TestCase
  include AttachmentsTestHelper
  include ActionDispatch::TestProcess

  def setup
    Account.stubs(:current).returns(Account.first)
    User.stubs(:current).returns(User.first)
    AwsWrapper::S3Object.stubs(:read).returns(nil)
  end

  def teardown
    super
    destroy_attachments
    Account.unstub(:current)
    User.unstub(:current)
    AwsWrapper::S3Object.unstub(:read)
  end

  def self.fixture_path
    File.join(Rails.root, 'test/api/fixtures/')
  end

  def test_product_feedback_worker_runs
    @account = Account.first
    Net::HTTP.any_instance.stubs(:request).returns(Helpdesk::Note.last)
    Helpdesk::Note.any_instance.stubs(:body).returns({ attachments: [1] }.to_json)
    Helpdesk::Note.any_instance.stubs(:code).returns('201')
    create_attachment(content: fixture_file_upload('files/attachment.txt', 'plain/text', :binary), attachable_type: 'UserDraft', attachable_id: '1')
    args = { 'attachment_ids': [@account.attachments.last.id], 'tags': [1, 2] }
    ProductFeedbackWorker.new.perform(args)
    Helpdesk::Note.any_instance.unstub(:body)
    Helpdesk::Note.any_instance.unstub(:code)
    assert_equal 0, ProductFeedbackWorker.jobs.size
  end

  def test_product_feedback_worker_no_attachments
    @account = Account.first
    Net::HTTP.any_instance.stubs(:request).returns(Helpdesk::Note.last)
    Helpdesk::Note.any_instance.stubs(:body).returns({ attachments: [1] }.to_json)
    Helpdesk::Note.any_instance.stubs(:code).returns('201')
    destroy_attachments
    args = { 'attachment_ids': [1] }
    ProductFeedbackWorker.new.perform(args)
    Helpdesk::Note.any_instance.unstub(:body)
    Helpdesk::Note.any_instance.unstub(:code)
    assert_equal 0, ProductFeedbackWorker.jobs.size
  end

  def destroy_attachments
    acc = Account.first
    return if acc.attachments.count.zero?

    acc.attachments.each(&:destroy)
  end
end
