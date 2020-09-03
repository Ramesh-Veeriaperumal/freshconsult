require_relative '../../test_helper'
Dir["#{Rails.root}/test/core/functional/helpdesk/attachment_test_cases/*.rb"].each { |file| require file }

class Helpdesk::AttachmentsControllerTest < ActionController::TestCase
  include CoreTicketsTestHelper
  include NoteTestHelper
  include CoreForumsTestHelper
  include CompanyTestHelper
  include CoreSolutionsTestHelper

  #test_cases
  include AttachmentPermissionsNegativeTests
  include AttachmentPermissionsTests

  def setup
    super
    $redis_others.perform_redis_op("set", "ARTICLE_SPAM_REGEX","(gmail|kindle|face.?book|apple|microsoft|google|aol|hotmail|aim|mozilla|quickbooks|norton).*(support|phone|number)")
    $redis_others.perform_redis_op("set", "PHONE_NUMBER_SPAM_REGEX", "(1|I)..?8(1|I)8..?85(0|O)..?78(0|O)6|(1|I)..?877..?345..?3847|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?8(0|O)(0|O)..?79(0|O)..?9(1|I)86|(1|I)..?8(0|O)(0|O)..?436..?(0|O)259|(1|I)..?8(0|O)(0|O)..?969..?(1|I)649|(1|I)..?844..?922..?7448|(1|I)..?8(0|O)(0|O)..?75(0|O)..?6584|(1|I)..?8(0|O)(0|O)..?6(0|O)4..?(1|I)88(0|O)|(1|I)..?877..?242..?364(1|I)|(1|I)..?844..?782..?8(0|O)96|(1|I)..?844..?895..?(0|O)4(1|I)(0|O)|(1|I)..?844..?2(0|O)4..?9294|(1|I)..?8(0|O)(0|O)..?2(1|I)3..?2(1|I)7(1|I)|(1|I)..?855..?58(0|O)..?(1|I)8(0|O)8|(1|I)..?877..?424..?6647|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?844..?83(0|O)..?8555|(1|I)..?8(0|O)(0|O)..?6(1|I)(1|I)..?5(0|O)(0|O)7|(1|I)..?8(0|O)(0|O)..?584..?46(1|I)(1|I)|(1|I)..?844..?389..?5696|(1|I)..?844..?483..?(0|O)332|(1|I)..?844..?78(0|O)..?675(1|I)|(1|I)..?8(0|O)(0|O)..?596..?(1|I)(0|O)65|(1|I)..?888..?573..?5222|(1|I)..?855..?4(0|O)9..?(1|I)555|(1|I)..?844..?436..?(1|I)893|(1|I)..?8(0|O)(0|O)..?89(1|I)..?4(0|O)(0|O)8|(1|I)..?855..?662..?4436")
    FakeWeb.register_uri(:put, Regexp.new("s3.amazonaws.com"), :body => "OK") 
    FakeWeb::StubSocket.any_instance.stubs(:read_timeout=).returns(true)
    FakeWeb::StubSocket.any_instance.stubs(:continue_timeout=).returns(true)
    FakeWeb::StubSocket.any_instance.stubs(:request_with_fakeweb).returns(true)
  end

  def test_attachment_redirect_url_contains_content_disposition_when_download_true
    create_ticket_with_attachments
    login_admin
    ticket = Helpdesk::Ticket.last
    attachment = ticket.attachments.first
    xhr :get, :show, {:id => attachment.id, download: true}
    assert_response :redirect
    assert_match Regexp.new(Helpdesk::Attachment.s3_path(attachment.id, "attachment.txt")), @response.redirect_url
    assert_match Regexp.new('response-content-disposition=attachment'), @response.redirect_url
  end

  def test_attachment_redirect_url_contains_no_content_disposition_when_no_download
    create_ticket_with_attachments
    login_admin
    ticket = Helpdesk::Ticket.last
    attachment = ticket.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :redirect
    assert_match Regexp.new(Helpdesk::Attachment.s3_path(attachment.id, "attachment.txt")), @response.redirect_url
    refute_match Regexp.new('response-content-disposition=attachment'), @response.redirect_url
  end

  def teardown
    super
    FakeWeb.clean_registry
  end

end
