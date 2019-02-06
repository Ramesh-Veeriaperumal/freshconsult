require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
require 'webmock/minitest'

Sidekiq::Testing.fake!

class AuditLogExportTest < ActiveSupport::TestCase
  def construct_args
    {
      basic_auth: {
        username: 'freshdesk-central-qa',
        password: 'freshdesk-central-qa'
      },
      export_job_id: 'aef24d8b-570c-4dcd-ba9e-12032754738a',
      time: 0,
      account_id: 1
    }
  end

  def construct_fail_args
    {
      basic_auth: {
        username: '',
        password: ''
      },
      user_email: 'sample@freshdesk.com',
      export_job_id: 'aef24d8b-570c-4dcd-ba9e-12032754738a',
      time: 0
    }
  end

  def test_export_url_response
    WebMock.allow_net_connect!
    args = construct_args
    Account.stubs(:current).returns(Account.first)
    User.stubs(:current).returns(User.first)
    value = AuditLogExport.new.perform(args)
    Export::Util.stubs(:build_attachment).returns(true)
    WebMock.disable_net_connect!
  ensure
    Export::Util.unstub(:build_attachment)
  end
end
