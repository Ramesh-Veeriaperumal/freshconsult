require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class DataExportSub < Helpdesk::ExportDataWorker
  def export_forums_data
    forum_categories = @current_account.forum_categories.all
    raise 'simple error'
  rescue StandardError => e
    log_export_errors('forums', forum_categories, 0, e)
  end

  def export_tickets_data
    i = 0
    @current_account.tickets.find_in_batches(batch_size: 300, include: [:notes, :attachments]) do |tkts|
      begin
        raise 'batch 0 error' if i.zero?

        xml_output = tkts.to_xml
        write_to_file("Tickets#{i}.xml", xml_output)
        i += 1
      rescue StandardError => e
        log_export_errors('tickets', tkts, i, e)
      end
    end
  end
end

class ExportDataWorker < ActionView::TestCase
  include AccountTestHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def setup
    @account = create_test_account
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @data_export = @account.data_exports.data_backup[0]
    @data_export.destroy if @data_export.present?
    @data_export = Account.current.data_exports.new(
      user: Account.current.users.where(active: true).first,
      source: DataExport::EXPORT_TYPE[:backup]
    )
    @data_export.save
    @args = {
      domain: @account.full_domain,
      email: 'sample@freshdesk.com'
    }
  end

  def teardown
    Account.unstub(:current)
  end

  def test_account_export
    DataExportSub.new(@args).perform
    @data_export.reload
    assert_equal @data_export.status, DataExport::EXPORT_STATUS[:completed]
    assert_equal @data_export.source, DataExport::EXPORT_TYPE[:backup]
    assert_equal @data_export.last_error, nil
  end
end
