require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

require Rails.root.join('spec', 'support', 'agent_helper.rb')

class CompanyWorkerTest < ActionView::TestCase
  include AgentHelper

  def setup
    @account = Account.first.make_current
    @agent = add_agent_to_account(@account, options = { role: 1, active: 1 })
  end

  def test_index
    args = { csv_hash: { 'Name' => 'agent_name', 'Email' => 'agent_email', 'Agent Type' => 'agent_type', 'Ticket scope' => 'ticket_scope', 'Roles' => 'agent_roles', 'Groups' => 'groups', 'Phone' => 'agent_phone', 'Mobile' => 'agent_mobile', 'Language' => 'agent_language', 'Timezone' => 'agent_time_zone', 'Last seen' => 'last_active_at' },
             user: @agent.user_id,
             portal_url: 'localhost.freshdesk-dev.com' }
    User.current = @agent.user
    Export::Util.stubs(:build_attachment).returns(true)
    ExportAgents.new.perform(args)
    data_export = @account.data_exports.last
    assert_equal data_export.status, DataExport::EXPORT_STATUS[:completed]
    assert_equal data_export.source, DataExport::EXPORT_TYPE[:agent]
    assert_equal data_export.last_error, nil
    data_export.destroy
    @agent.destroy
  ensure
    Export::Util.unstub(:build_attachment)
  end
end
