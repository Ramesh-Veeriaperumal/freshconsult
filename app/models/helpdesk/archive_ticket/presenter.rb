class Helpdesk::ArchiveTicket < ActiveRecord::Base
  include RepresentationHelper
  include TicketsNotesHelper
  include TicketPresenter::PresenterHelper

  api_accessible :central_publish do |at|
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
end
