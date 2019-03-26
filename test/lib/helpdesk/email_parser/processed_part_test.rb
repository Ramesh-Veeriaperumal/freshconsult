require_relative '../../../api/unit_test_helper'

class ProcessedPartTest < ActionView::TestCase

  def setup
    Account.stubs(:current).returns(Account.first)
    @part = Mail::Part.new do
      content_type 'text/html;'
      body '<h1>This is HTML</h1>'
    end
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_processed_part_with_attachment
    Mail::Part.any_instance.stubs(:attachment?).returns(true)
    part = Helpdesk::EmailParser::ProcessedPart.new(@part)
    assert_equal true, part.attachments.length > 0
  end

  def test_processed_part_with_attachment_content_type
    Mail::Part.any_instance.stubs(:content_disposition).returns('/attachment/i')
    part = Helpdesk::EmailParser::ProcessedPart.new(@part)
    assert_equal true, part.attachments.length > 0
  end

  def test_processed_part_with_attachment_with_transfer_encoding
    Mail::Part.any_instance.stubs(:content_disposition).returns('/attachment/i')
    Mail::Part.any_instance.stubs(:content_transfer_encoding).returns('UUENCODE')
    Mail::Part.any_instance.stubs(:raw_source).returns("begin 234 ..\r\nend")
    part = Helpdesk::EmailParser::ProcessedPart.new(@part)
    assert_equal true, part.attachments.length > 0
  end

  def test_processed_part_with_attachment_content_type_with_filename
    Mail::Part.any_instance.stubs(:content_disposition).returns('/attachment/i')
    Mail::Part.any_instance.stubs(:filename).returns('attachment.html')
    part = Helpdesk::EmailParser::ProcessedPart.new(@part)
    assert_equal true, part.attachments.length > 0
  end

  def test_processed_part_with_attachment_content_type_error
    Mail::Part.any_instance.stubs(:content_disposition).returns('/attachment/i')
    Mail::Part.any_instance.stubs(:content_transfer_encoding).raises(StandardError.new('error'))
    Helpdesk::EmailParser::ProcessedPart.new(@part)
  rescue Helpdesk::EmailParser::ParseError => e
    assert_equal true, e.message.present?
  end

  def test_processed_part_with_text_mime
    Mail::Part.any_instance.stubs(:mime_type).returns('text/plain')
    part = Helpdesk::EmailParser::ProcessedPart.new(@part)
    assert_equal '<h1>This is HTML</h1>', part.text
  end

  def test_processed_part_with_text_mime_error
    Mail::Part.any_instance.stubs(:mime_type).returns('text/plain')
    Helpdesk::EmailParser::ProcessedPart.any_instance.stubs(:detect_encoding_from_content).raises(StandardError.new('error'))
    part = Helpdesk::EmailParser::ProcessedPart.new(@part)
    assert_equal '<h1>This is HTML</h1>', part.text
  end

  def test_processed_part_with_html_mime
    Mail::Part.any_instance.stubs(:mime_type).returns('text/html')
    part = Helpdesk::EmailParser::ProcessedPart.new(@part)
    assert_equal '<h1>This is HTML</h1>', part.html
  end

  def test_processed_part_with_html_mime_error
    Mail::Part.any_instance.stubs(:mime_type).returns('text/html')
    Helpdesk::EmailParser::ProcessedPart.any_instance.stubs(:detect_encoding_from_content).raises(StandardError.new('error'))
    part = Helpdesk::EmailParser::ProcessedPart.new(@part)
    assert_equal '<h1>This is HTML</h1>', part.html
  end

  def test_processed_part_with_rfc822_mime
    Mail::Part.any_instance.stubs(:mime_type).returns('message/rfc822')
    part = Helpdesk::EmailParser::ProcessedPart.new(@part)
    assert_not_equal '<h1>This is HTML</h1>', part.html
    assert_equal true, part.is_child_part?
  end

  def test_processed_part_with_rfc822_mime_and_html
    Helpdesk::EmailParser::ProcessedMail.any_instance.stubs(:html).returns('html')
    Mail::Part.any_instance.stubs(:mime_type).returns('message/rfc822')
    part = Helpdesk::EmailParser::ProcessedPart.new(@part)
    assert_not_equal '<h1>This is HTML</h1>', part.html
    assert_equal true, part.is_child_part?
  end

  def test_processed_part_with_rfc822_mime_parse_error
    Mail::Part.any_instance.stubs(:mime_type).returns('message/rfc822')
    Mail::Part.any_instance.stubs(:body).raises(Helpdesk::EmailParser::ParseError.new('err'))
    Helpdesk::EmailParser::ProcessedPart.new(@part)
  rescue Helpdesk::EmailParser::ParseError => e
    assert_equal true, e.message.present?
  end

  def test_processed_part_with_rfc822_mime_general_error
    Mail::Part.any_instance.stubs(:mime_type).returns('message/rfc822')
    Mail::Part.any_instance.stubs(:body).raises(StandardError.new('err'))
    Helpdesk::EmailParser::ProcessedPart.new(@part)
  rescue Helpdesk::EmailParser::ParseError => e
    assert_equal true, e.message.present?
  end

  def test_processed_part_delivery_status_report_part
    Mail::Part.any_instance.stubs(:mime_type).returns(nil)
    Mail::Part.any_instance.stubs(:delivery_status_report_part?).returns(true)
    part = Helpdesk::EmailParser::ProcessedPart.new(@part)
    assert_equal '', part.text
    assert_equal true, part.is_delivery_status_part?
  end

  def test_processed_part_delivery_status_report_part_error
    Mail::Part.any_instance.stubs(:mime_type).returns(nil)
    Mail::Part.any_instance.stubs(:delivery_status_report_part?).returns(true)
    Helpdesk::EmailParser::ProcessedPart.any_instance.stubs(:get_delivery_status_data_values).raises(StandardError.new('error'))
    Helpdesk::EmailParser::ProcessedPart.new(@part)
  rescue Helpdesk::EmailParser::ParseError => e
    assert_equal true, e.message.present?
  end

  def test_processed_part_known_attachment_type_false
    Mail::Part.any_instance.stubs(:mime_type).returns(nil)
    Mail::Part.any_instance.stubs(:content_type).returns(nil)
    part = Helpdesk::EmailParser::ProcessedPart.new(@part)
    assert_equal '<h1>This is HTML</h1>', part.text
  end

  def test_processed_part_known_attachment_type_true
    Mail::Part.any_instance.stubs(:mime_type).returns('application/json')
    Mail::Part.any_instance.stubs(:content_type).returns('application/json')
    part = Helpdesk::EmailParser::ProcessedPart.new(@part)
    assert_equal true, part.attachments.length > 0
  end

  def test_processed_part_known_attachment_type_true_and_decoded_error
    Mail::Part.any_instance.stubs(:mime_type).returns('application/json')
    Mail::Part.any_instance.stubs(:content_type).returns('application/json')
    Mail::Body.any_instance.stubs(:decoded).raises(Mail::UnknownEncodingType.new('err'))
    Helpdesk::EmailParser::ProcessedPart.new(@part)
  rescue Exception => e
    assert_equal true, e.message.present?
  end

  def test_processed_part_errors
    Mail::Part.any_instance.stubs(:multipart?).raises(StandardError.new('error'))
    Helpdesk::EmailParser::ProcessedPart.new(@part)
  rescue Helpdesk::EmailParser::ParseError => e
    assert_equal true, e.message.present?
  end
end
