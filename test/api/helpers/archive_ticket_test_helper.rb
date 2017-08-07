module ArchiveTicketTestHelper
  def enable_archive_tickets
    @account.enable_ticket_archiving(0)
    yield
  ensure
    disable_archive_tickets
  end

  def disable_archive_tickets
    @account.make_current
    @account.account_additional_settings.additional_settings[:archive_days] = nil
    @account.account_additional_settings.save
    @account.features.archive_tickets.destroy
  end
end
