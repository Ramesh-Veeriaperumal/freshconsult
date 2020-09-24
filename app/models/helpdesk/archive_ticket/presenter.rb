class Helpdesk::ArchiveTicket < ActiveRecord::Base
  include RepresentationHelper
  include TicketsNotesHelper
  include TicketPresenter::PresenterHelper

  DISALLOWED_PAYLOAD_TYPES = ['archive_ticket_update', 'archive_ticket_destroy'].freeze

  api_accessible :central_publish do |at|
    at.add :ticket_id
    at.add :parent_id
    at.add proc { |x| x.utc_format(x.parse_to_date_time(x.safe_send(:archive_created_at))) }, as: :archive_created_at
    at.add proc { |x| x.utc_format(x.parse_to_date_time(x.safe_send(:archive_updated_at))) }, as: :archive_updated_at
  end

  def relationship_with_account
    'archive_tickets'
  end

  def parent_id
    parent_ticket.try(:id)
  end

  def self.central_publish_enabled?
    Account.current.archive_ticket_central_publish_enabled?
  end

  def central_publish_worker_class
    'CentralPublishWorker::ArchiveTicketWorker'
  end

  def self.disallow_payload?(payload_type)
    return true if DISALLOWED_PAYLOAD_TYPES.include? payload_type

    super
  end
end
