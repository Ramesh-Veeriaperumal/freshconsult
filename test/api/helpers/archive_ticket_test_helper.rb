module ArchiveTicketTestHelper
  ARCHIVE_BODY = JSON.parse(File.read("#{Rails.root}/test/api/fixtures/archive_ticket_body.json"))['archive_ticket_association']

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

  def stub_archive_assoc(options = {})
    random_ticket_id = options[:ticket_id] || Faker::Number.number(10)
    display_id = options[:display_id] || Faker::Number.number(10)
    requester_id = options[:requester_id] || Account.current.try(:users).try(:first)
    responder_id = options[:responder_id] || Account.current.try(:technicians).try(:first)
    account_id = options[:account_id] || Account.current.try(:id) || Account.last.try(:id)

    default_options = {
      account_id: account_id,
      requester_id: requester_id,
      responder_id: responder_id,
      display_id: display_id,
      ticket_id: random_ticket_id,
      association_data: {
        'helpdesk_tickets' => {
          'ticket_id' => random_ticket_id,
          'requester_id' => requester_id,
          'responder_id' => responder_id,
          'account_id' => account_id,
          'display_id' => display_id
        },
        'helpdesk_tickets_association' => {
          'ticket_states' => {
            'ticket_id' => random_ticket_id,
            'account_id' => account_id
          }
        }
      }
    }.merge(options)

    Helpdesk::ArchiveTicket
      .any_instance.stubs(:read_from_s3)
      .returns(Helpdesk::ArchiveTicketAssociation.new(ARCHIVE_BODY.merge(default_options)))
    yield
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
  end
end
