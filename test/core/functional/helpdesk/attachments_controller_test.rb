require_relative '../../test_helper'
Dir["#{Rails.root}/test/core/functional/helpdesk/attachment_test_cases/*.rb"].each { |file| require file }

class Helpdesk::AttachmentsControllerTest < ActionController::TestCase
  include TicketsTestHelper
  include NoteTestHelper
  include ForumsTestHelper
  include CompanyTestHelper
  include SolutionsTestHelper

  #test_cases
  include AttachmentPermissionsNegativeTests
  include AttachmentPermissionsTests

  def setup
    super
    $redis_others.perform_redis_op("set", "ARTICLE_SPAM_REGEX","(gmail|kindle|face.?book|apple|microsoft|google|aol|hotmail|aim|mozilla|quickbooks|norton).*(support|phone|number)")
    @account.launch :attachments_scope
    FakeWeb.register_uri(:put, Regexp.new("s3.amazonaws.com"), :body => "OK") 
    FakeWeb::StubSocket.any_instance.stubs(:read_timeout=).returns(true)
    FakeWeb::StubSocket.any_instance.stubs(:continue_timeout=).returns(true)
    FakeWeb::StubSocket.any_instance.stubs(:request_with_fakeweb).returns(true)
  end
  
  def teardown
    FakeWeb.clean_registry
  end

end