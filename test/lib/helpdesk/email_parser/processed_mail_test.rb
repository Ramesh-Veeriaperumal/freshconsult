require_relative '../../../api/unit_test_helper'
require 'faker'

class ProcessedMailTest < ActionView::TestCase
  def stub_mail_object(options = {})
    mail = Mail.new do
      to      options[:to] || Faker::Internet.email.to_s
      from    options[:from] || "#{Faker::Name.name} <#{Faker::Internet.email}>"
      cc      options[:cc] || Faker::Internet.email.to_s
      subject options[:subject] || 'First multipart email sent with Mail'
      in_reply_to options[:in_reply_to] || ''
      references options[:references] || ''
    end
    text_part = Mail::Part.new do
      body 'This is plain text'
    end
    html_part = Mail::Part.new do
      content_type 'text/html;'
      body '<h1>This is HTML</h1>'
    end
    mail.text_part = text_part
    mail.html_part = html_part
    Mail.stubs(:new).returns(mail)
  end

  def test_processed_mail_runs
    processed_email = Helpdesk::EmailParser::ProcessedMail.new(Faker::Internet.email)
    processed_email.get_header_field('x-content-type')
  end

  def test_processed_mail_with_multipart
    stub_mail_object
    Mail::Message.any_instance.stubs(:in_reply_to).returns([Faker::Internet.email.to_s, Faker::Internet.email.to_s])
    Mail::Message.any_instance.stubs(:references).returns([Faker::Internet.email.to_s, Faker::Internet.email.to_s])
    processed_email = Helpdesk::EmailParser::ProcessedMail.new(Faker::Internet.email)
  ensure
    Mail.unstub(:new)
    Mail::Message.any_instance.unstub(:in_reply_to)
    Mail::Message.any_instance.unstub(:references)
  end

  def test_process_mail_raises_parsing_error
    Helpdesk::EmailParser::ProcessedPart.stubs(:new).raises(Helpdesk::EmailParser::ParseError)
    Helpdesk::EmailParser::ProcessedMail.new(Faker::Internet.email)
  rescue Helpdesk::EmailParser::ParseError => e
  ensure
    Helpdesk::EmailParser::ProcessedPart.unstub(:new)
  end

  def test_process_mail_raises_exception
    Helpdesk::EmailParser::ProcessedPart.stubs(:new).raises(StandardError)
    Helpdesk::EmailParser::ProcessedMail.new(Faker::Internet.email)
  rescue StandardError => e
  ensure
    Helpdesk::EmailParser::ProcessedPart.unstub(:new)
  end

  def test_process_mail_with_encoded_mail_values
    stub_mail_object(from: '=?v?B?g?=', cc: '=?v?B?ddsag1234d?=', subject: '=?First multipart email sent with Mail', in_reply_to: "<#{Faker::Internet.email}>", references: "<#{Faker::Internet.email}>")
    Helpdesk::EmailParser::ProcessedMail.new(Faker::Internet.email)
  ensure
    Mail.unstub(:new)
  end

  def test_fetch_header_data_raises_exceptions
    stub_mail_object(from: "#{Faker::Name.name} <#{Faker::Internet.email}>", subject: '=?v?B?First multipart email sent with Mail?=')
    Mail::Field.any_instance.stubs(:value).raises(StandardError)
    Mail::Message.any_instance.stubs(:from).raises(StandardError)
    Mail::AddressContainer.any_instance.stubs(:kind_of?).raises(StandardError)
    Helpdesk::EmailParser::ProcessedMail.new(Faker::Internet.email)
  rescue StandardError => e
  ensure
    Mail.unstub(:new)
    Mail::Field.any_instance.unstub(:value)
    Mail::Message.any_instance.unstub(:from)
    Mail::AddressContainer.any_instance.unstub(:kind_of?)
  end

  def test_processed_mail_with_empty_parts
    stub_mail_object(from: "#{Faker::Name.name} <#{Faker::Internet.email}>", subject: 'First multipart email sent with Mail')
    Mail::Message.any_instance.stubs(:all_parts).returns([])
    Helpdesk::EmailParser::ProcessedMail.new(Faker::Internet.email)
  ensure
    Mail.unstub(:new)
    Mail::Message.any_instance.unstub(:all_parts)
  end

  def test_all_parts_processing_raises_parse_error
    stub_mail_object(from: "#{Faker::Name.name} <#{Faker::Internet.email}>", subject: '=?v?B?First multipart email sent with Mail?=')
    Helpdesk::EmailParser::ProcessedPart.stubs(:new).raises(Helpdesk::EmailParser::ParseError)
    assert_raises Helpdesk::EmailParser::ParseError do
      Helpdesk::EmailParser::ProcessedMail.new(Faker::Internet.email)
    end
  ensure
    Mail.unstub(:new)
    Helpdesk::EmailParser::ProcessedPart.unstub(:new)
  end

  def test_all_parts_processing_raises_standard_error
    stub_mail_object(from: "#{Faker::Name.name} <#{Faker::Internet.email}>", subject: '=?v?B?First multipart email sent with Mail?=')
    Mail::Message.any_instance.stubs(:all_parts).raises(StandardError)
    Helpdesk::EmailParser::ProcessedMail.new(Faker::Internet.email)
  rescue StandardError => e
  ensure
    Mail.unstub(:new)
    Mail::Message.any_instance.unstub(:all_parts)
  end

  def test_all_parts_processing_with_delivery_and_child_part
    stub_mail_object(from: "#{Faker::Name.name} <#{Faker::Internet.email}>", subject: '=?v?B?First multipart email sent with Mail?=')
    Helpdesk::EmailParser::ProcessedPart.any_instance.stubs(:is_delivery_status_part?).returns(true)
    Helpdesk::EmailParser::ProcessedPart.any_instance.stubs(:is_child_part?).returns(true)
    Helpdesk::EmailParser::ProcessedMail.new(Faker::Internet.email)
  rescue Helpdesk::EmailParser::ParseError => e
  ensure
    Mail.unstub(:new)
    Helpdesk::EmailParser::ProcessedPart.any_instance.unstub(:is_delivery_status_part?)
    Helpdesk::EmailParser::ProcessedPart.any_instance.unstub(:is_child_part?)
  end

  def test_processed_mail_without_charset
    processed_mail = Helpdesk::EmailParser::ProcessedMail.new(Faker::Internet.email)
    Mail::Message.any_instance.stubs(:charset).returns(nil)
    processed_mail.safe_send(:fetch_mail_header_default_charset, 'UTF-8')
    assert_equal processed_mail.safe_send(:decoded_mail_body), ''
    assert_equal processed_mail.safe_send(:regular_mail_with_attachment?), false
  ensure
    Mail::Message.any_instance.unstub(:charset)
  end

  def test_processed_mail_header_raises_error
    processed_mail = Helpdesk::EmailParser::ProcessedMail.new(Faker::Internet.email)
    Mail::Message.any_instance.stubs(:header).raises(StandardError)
    assert_raises StandardError do
      processed_mail.safe_send(:get_header)
    end
    assert_raises StandardError do
      processed_mail.safe_send(:get_header_data)
    end
    assert_raises StandardError do
      processed_mail.safe_send(:get_decoded_subject)
    end
  end

  def test_decoded_mail_body_raises_exception
    processed_mail = Helpdesk::EmailParser::ProcessedMail.new(Faker::Internet.email)
    Mail::Body.any_instance.stubs(:decoded).raises(Mail::UnknownEncodingType)
    assert_raises Mail::UnknownEncodingType do
      processed_mail.safe_send(:decoded_mail_body)
    end
  ensure
    Mail::Body.any_instance.unstub(:decoded)
  end

  def test_cc_address_raises_exception
    stub_mail_object
    processed_mail = Helpdesk::EmailParser::ProcessedMail.new(Faker::Internet.email)
    Mail::Field.any_instance.stubs(:value).raises(StandardError)
    Mail::Message.any_instance.stubs(:cc).raises(StandardError)
    processed_mail.safe_send(:get_cc_address)
  ensure
    Mail.unstub(:new)
    Mail::Field.any_instance.unstub(:value)
    Mail::Message.any_instance.unstub(:cc)
  end
end
