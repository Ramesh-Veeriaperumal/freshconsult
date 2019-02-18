require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
require Rails.root.join('spec', 'support', 'account_helper.rb')

Sidekiq::Testing.fake!

class AuditLogExportTest < ActiveSupport::TestCase
  include AccountHelper

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
    account = Account.first.nil? ? create_test_account(Faker::Lorem.word) : Account.first
    WebMock.allow_net_connect!
    args = construct_args
    account = Account.first.nil? ? Account.first : create_test_account
    Account.stubs(:current).returns(account)
    User.stubs(:current).returns(User.first)
    value = AuditLogExport.new.perform(args)
    Export::Util.stubs(:build_attachment).returns(true)
  ensure
    WebMock.disable_net_connect!
    Export::Util.unstub(:build_attachment)
    Account.unstub(:current)
    User.unstub(:current)
  end
end
