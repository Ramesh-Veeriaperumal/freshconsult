require_relative '../unit_test_helper'

class SendGridDomainUpdatesTest < ActionView::TestCase
  include Redis::OthersRedis

  def setup
    Account.stubs(:current).returns(StubAccount.new)
    Account.stubs(:find_by_id).returns(StubAccount.new)
  end

  def teardown
    Account.unstub(:current)
    Account.unstub(:find_by_id)
  end

  def get_others_redis_key(_param)
    100
  end

  class ConversionMetric
    def spam_score=(_param = nil)
      1
    end

    def spam_score_will_change!
      1
    end

    def save
      true
    end
  end

  class StubAccount
    def id
      1
    end

    def display_id
      1
    end

    def launched?(_param = nil)
      true
    end

    def conversion_metric
      ConversionMetric.new
    end

    def full_domain
      '/support/i'
    end

    def admin_email
      'email'
    end

    def launch(_params = nil)
      1
    end

    def enable_setting(_params = nil)
      true
    end

    def subscription(_params = nil)
      Attr.new
    end

    def helpdesk_name
      'h_name'
    end
  end

  class ResponseStub
    def initialize(code)
      @code = code
    end

    def code
      @code
    end

    def message
      'message'
    end
  end

  class Attr
    def update_attributes(_params = nil)
      true
    end
  end

  def test_perform
    Rails.env.stubs(:development?).returns(false)
    HTTParty.stubs(:safe_send).returns(ResponseStub.new(400))
    SendgridDomainUpdates.new.perform({ 'action' => 'delete', 'domain' => 'dom' })
    assert_equal response.status, 200

    HTTParty.stubs(:safe_send).returns(ResponseStub.new(400))
    SendgridDomainUpdates.new.perform({ 'action' => '', 'domain' => 'dom' })
    assert_equal response.status, 200

    FreshdeskErrorsMailer.stubs(:error_email).returns(true)
    HTTParty.stubs(:safe_send).returns(ResponseStub.new(200))
    SendgridDomainUpdates.new.perform({ 'action' => 'create', 'domain' => 'dom', 'vendor_id' => '1' })
    assert_equal response.status, 200

    HTTParty.stubs(:safe_send).returns(ResponseStub.new(200))
    SendgridDomainUpdates.new.perform({ 'action' => 'delete', 'domain' => 'dom' })
    assert_equal response.status, 200

    HTTParty.stubs(:safe_send).returns(ResponseStub.new(200))
    SendgridDomainUpdates.new.perform({ 'domain' => 'dom' })
    assert_equal response.status, 200
  ensure
    FreshdeskErrorsMailer.unstub(:error_email)
    Rails.env.unstub(:development?)
    HTTParty.unstub(:safe_send)
  end

  def test_delete_record
    SendgridDomainUpdates.any_instance.stubs(:send_request).returns(ResponseStub.new(204))
    SendgridDomainUpdates.new.delete_record('domain', 1)
    assert_equal response.status, 200
  ensure
    SendgridDomainUpdates.unstub(:send_request)
  end

  def test_create_record
    status = ShardMapping.find_by_account_id(Account.current.id)[:status]
    Freemail.stubs(:free_or_disposable?).returns(true)
    FreshdeskErrorsMailer.any_instance.stubs(:error_email).returns(true)
    SendgridDomainUpdates.any_instance.stubs(:send_request).returns(ResponseStub.new(200))
    SendgridDomainUpdates.new.create_record('domain', 1)

    SendgridDomainUpdates.any_instance.stubs(:get_account_signup_params).returns({ 'account_details' => 'details', 'api_response' => { 'RISK SCORE' => 4, 'status' => 4, 'REASON' => 'reason' }})
    Email::AntiSpam.stubs(:scan).returns({ 'RISK SCORE' => 4, 'status' => 4, 'REASON' => 'reason' })
    SendgridDomainUpdates.any_instance.stubs(:notify_account_blocks).returns(true)
    SendgridDomainUpdates.any_instance.stubs(:update_freshops_activity).returns(true)
    SendgridDomainUpdates.new.create_record('domain', 2)

    SendgridDomainUpdates.any_instance.stubs(:get_account_signup_params).returns({ 'account_details' => { 'source_ip' => 'ip', 'email' => 'email' }, 'api_response' => { 'RISK SCORE' => 5, 'status' => 5, 'REASON' => 'reason' } })
    Email::AntiSpam.stubs(:scan).returns({ 'RISK SCORE' => 5, 'status' => 5, 'REASON' => 'reason' })
    SendgridDomainUpdates.any_instance.stubs(:notify_account_blocks).returns(true)
    SendgridDomainUpdates.any_instance.stubs(:update_freshops_activity).returns(true)
    SendgridDomainUpdates.new.create_record('domain', 2)
  ensure
    ShardMapping.find_by_account_id(Account.current.id).update_attributes(:status => status)
    Email::AntiSpam.unstub(:scan)
    SendgridDomainUpdates.any_instance.unstub(:notify_account_blocks)
    SendgridDomainUpdates.any_instance.unstub(:update_freshops_activity)
    SendgridDomainUpdates.any_instance.unstub(:send_request)
    SendgridDomainUpdates.any_instance.unstub(:get_account_signup_params)
    FreshdeskErrorsMailer.unstub(:error_email)
    Freemail.unstub(:free_or_disposable?)
  end
end
