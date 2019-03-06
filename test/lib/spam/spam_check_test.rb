require_relative '../../api/unit_test_helper'
['account_test_helper.rb'].each { |file| require Rails.root.join("test/core/helpers/#{file}") }

class SpamCheckTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    @account = Account.current
    @user = @account.nil? ? create_test_account : @account.users.first
    User.stubs(:current).returns(@user)
    ShardMapping.any_instance.stubs(:update_attributes).returns(true)
    Subscription.any_instance.stubs(:update_attributes).returns(true)
  end

  def teardown
    User.unstub(:current)
    ShardMapping.any_instance.unstub(:update_attributes)
    Subscription.any_instance.unstub(:update_attributes)
  end

  def test_spam_content_for_spam_http_success_response
    $redis_others.perform_redis_op('del', 'SPAM_EMAIL_ACCOUNTS')
    Fdadmin::APICalls.stubs(:make_api_request_to_global).returns(true)
    Net::HTTP::Persistent.any_instance.stubs(:request).returns(Net::HTTPSuccess.new(200, 2, Faker::Lorem.word))
    Net::HTTPSuccess.any_instance.stubs(:body).returns({ 'is_spam' => true, 'rules' => ['Test'] }.to_json)
    Net::HTTP.stubs(:get_response).returns(Net::HTTPSuccess.new(200, 2, Faker::Lorem.word))
    spam_checker = Spam::SpamCheck.new
    spam_value = spam_checker.check_spam_content(Faker::Lorem.word, "Body : #{Faker::Internet.url} #{Faker::Lorem.paragraphs}", {})
    assert_equal spam_value, 0
  ensure
    $redis_others.perform_redis_op('del', 'SPAM_EMAIL_ACCOUNTS')
    Fdadmin::APICalls.unstub(:make_api_request_to_global)
    Net::HTTP::Persistent.any_instance.unstub(:request)
    Net::HTTPSuccess.any_instance.unstub(:body)
    Net::HTTP.unstub(:get_response)
  end

  def test_spam_content_with_application_xml_content_type
    Fdadmin::APICalls.stubs(:make_api_request_to_global).returns(true)
    Net::HTTP::Persistent.any_instance.stubs(:request).returns(Net::HTTPSuccess.new(200, 2, Faker::Lorem.word))
    Net::HTTPSuccess.any_instance.stubs(:body).returns({ 'is_spam' => true, 'rules' => ['Test'] }.to_json)
    Net::HTTP.stubs(:get_response).returns(Net::HTTPSuccess.new(200, 2, Faker::Lorem.word))
    spam_checker = Spam::SpamCheck.new
    spam_value = spam_checker.check_spam_content(Faker::Lorem.word, "Content-Type : application/xml, Body : #{Faker::Internet.url} #{Faker::Lorem.paragraphs}", {})
    assert_equal spam_value, 3
  ensure
    Fdadmin::APICalls.unstub(:make_api_request_to_global)
    Net::HTTP::Persistent.any_instance.unstub(:request)
    Net::HTTPSuccess.any_instance.unstub(:body)
    Net::HTTP.unstub(:get_response)
  end

  def test_spam_content_for_spam_less_http_response
    Net::HTTP::Persistent.any_instance.stubs(:request).returns(Net::HTTPResponse.new(200, 2, Faker::Lorem.word))
    Net::HTTPResponse.any_instance.stubs(:body).returns({ 'is_spam' => false, 'rules' => ['Test'] }.to_json)
    Net::HTTP.stubs(:get_response).returns(Net::HTTPResponse.new(200, 2, Faker::Lorem.word))
    spam_checker = Spam::SpamCheck.new
    spam_value = spam_checker.check_spam_content(Faker::Lorem.word, "#{Faker::Internet.url} #{Faker::Lorem.paragraphs}", {})
    assert_equal spam_value, 9
  ensure
    Net::HTTP::Persistent.any_instance.unstub(:request)
    Net::HTTPResponse.any_instance.unstub(:body)
    Net::HTTP.unstub(:get_response)
  end

  def test_spam_content_for_http_redirection_response
    Net::HTTP::Persistent.any_instance.stubs(:request).returns(Net::HTTPSuccess.new(200, 2, Faker::Lorem.word))
    Net::HTTPSuccess.any_instance.stubs(:body).returns({ 'is_spam' => false, 'rules' => ['Test'] }.to_json)
    Net::HTTP.stubs(:get_response).returns(Net::HTTPRedirection.new(200, 2, Faker::Lorem.word))
    spam_checker = Spam::SpamCheck.new
    spam_value = spam_checker.check_spam_content(Faker::Lorem.word, "#{Faker::Internet.url} #{Faker::Lorem.paragraphs}", {})
    assert_equal spam_value, 9
  ensure
    Net::HTTP::Persistent.any_instance.unstub(:request)
    Net::HTTPSuccess.any_instance.unstub(:body)
    Net::HTTP.unstub(:get_response)
  end

  def test_spam_content_for_http_response_with_flagged_spam_templates
    $redis_others.perform_redis_op('rpush', 'SPAM_CHECK_TEMPLATE_FLAGGED_RULES', 'one')
    $redis_others.perform_redis_op('del', 'SPAM_EMAIL_ACCOUNTS')
    Fdadmin::APICalls.stubs(:make_api_request_to_global).returns(true)
    Net::HTTP::Persistent.any_instance.stubs(:request).returns(Net::HTTPSuccess.new(200, 2, Faker::Lorem.word))
    Net::HTTPSuccess.any_instance.stubs(:body).returns({ 'is_spam' => true, 'rules' => ['one'] }.to_json)
    Net::HTTP.stubs(:get_response).returns(Net::HTTPRedirection.new(200, 2, Faker::Lorem.word))
    spam_checker = Spam::SpamCheck.new
    spam_value = spam_checker.check_spam_content(Faker::Lorem.word, "#{Faker::Internet.url} #{Faker::Lorem.paragraphs}", {})
    assert_equal spam_value, 9
  ensure
    $redis_others.perform_redis_op('del', 'SPAM_CHECK_TEMPLATE_FLAGGED_RULES')
    $redis_others.perform_redis_op('del', 'SPAM_EMAIL_ACCOUNTS')
    Fdadmin::APICalls.unstub(:make_api_request_to_global)
    Net::HTTP::Persistent.any_instance.unstub(:request)
    Net::HTTPSuccess.any_instance.unstub(:body)
    Net::HTTP.unstub(:get_response)
  end

  def test_for_spam_content
    Akismetor.stubs(:spam?).returns(true)
    spam_checker = Spam::SpamCheck.new
    spam_value = spam_checker.safe_send(:is_spam_content, CGI.unescapeHTML(spam_checker.build_content(Faker::Lorem.word, Faker::Lorem.paragraphs)), @user.id, '127.0.0.1', 'Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.2) Gecko/20100115 Firefox/3.6')
    assert_equal spam_value, 3
  ensure
    Akismetor.unstub(:spam?)
  end

  def test_for_spam_content_raises_error
    Akismetor.stubs(:spam?).raises(StandardError)
    spam_checker = Spam::SpamCheck.new
    spam_value = spam_checker.safe_send(:is_spam_content, CGI.unescapeHTML(spam_checker.build_content(Faker::Lorem.word, Faker::Lorem.paragraphs)), @user.id, '127.0.0.1', 'Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.2) Gecko/20100115 Firefox/3.6')
    assert_equal spam_value, 9
  ensure
    Akismetor.unstub(:spam?)
  end

  def test_for_redirectional_links_in_spam
    spam_checker = Spam::SpamCheck.new
    value = spam_checker.has_more_redirection_links?(Faker::Lorem.word, "#{Faker::Internet.url} #{Faker::Lorem.paragraphs}", {})
    assert_equal value, false
  end

  def test_spam_content_raises_error
    spam_checker = Spam::SpamCheck.new
    spam_value = spam_checker.check_spam_content(Faker::Lorem.word, Faker::Lorem.paragraphs, {})
  end
end
