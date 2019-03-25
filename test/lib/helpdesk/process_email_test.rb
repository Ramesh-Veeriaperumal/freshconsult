require_relative '../../test_helper'
require_relative '../../api/unit_test_helper'
require_relative '../../core/helpers/account_test_helper'
require_relative '../../core/helpers/tickets_test_helper'

# Test cases for email process
class ProcessEmailTest < ActiveSupport::TestCase
  include AccountTestHelper
  include CoreTicketsTestHelper

  def setup
    super
    @account = Account.first || create_test_account
    Account.stubs(:current).returns(@account)
    Account.stubs(:find_by_full_domain).returns(@account)
    raise "Account is nil" if @account.blank?
  end

  def teardown
    Account.unstub(:current)
    Account.unstub(:find_by_full_domain)
  end

  def test_collab_email_reply_invited
    req_params = { subject: 'Invited to Team Huddle - [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, true
  end

  def test_collab_email_reply_mentioned
    req_params = { subject: 'Mentioned in Team Huddle - [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, true
  end

  def test_collab_email_reply_group_mentioned
    req_params = { subject: 'mentioned in Team Huddle - [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, true
  end

  def test_collab_email_reply_reply
    req_params = { subject: 'Reply in Team Huddle - [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, true
  end

  def test_collab_email_reply_follower_multi_messages
    req_params = { subject: 'Team Huddle - New Messages in [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, true
  end

  def test_collab_email_reply_follower_single_message
    req_params = { subject: 'Team Huddle - New Message in [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, true
  end

  def test_collab_email_reply_should_process_1
    req_params = { subject: 'Invited to Team Huddle -y [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, false
  end

  def test_collab_email_reply_should_process_2
    req_params = { subject: 'Team Huddle - [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, false
  end

  def test_collab_email_reply_should_process_3
    req_params = { subject: 'Random subject to an email reply' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, false
  end

  def test_collab_email_reply_should_process_4
    req_params = { subject: 'Random subject to an email reply' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, false
  end

  def test_collab_email_reply_should_process_5
    req_params = { subject: 'reply in Team Huddle - [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, false
  end
end
