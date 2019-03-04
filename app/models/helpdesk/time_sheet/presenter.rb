class Helpdesk::TimeSheet < ActiveRecord::Base
  include RepresentationHelper
  include Publish

  DATETIME_FIELDS = [:start_time, :executed_at, :created_at, :updated_at].freeze

  acts_as_api

  api_accessible :central_publish do |t|
    t.add :id
    t.add :account_id
    t.add :ticket_id, if: :belongs_to_ticket?
    t.add :archive_ticket_id, if: :belongs_to_archive_ticket?
    t.add :billable
    t.add :time_spent
    t.add :timer_running
    t.add :note
    t.add :user_id
    DATETIME_FIELDS.each do |key|
      t.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
    end
  end

  api_accessible :central_publish_associations do |t|
    t.add :user, template: :central_publish
  end

  api_accessible :central_publish_destroy do |t|
    t.add :id
    t.add :account_id
    t.add :ticket_id
  end

  def self.central_publish_enabled?
    Account.current.launched?(:time_sheets_central_publish)
  end

  def ticket_id
    belongs_to_ticket? ? workable.display_id : Helpdesk::ArchiveTicket.unscoped { workable.display_id }
  end
  alias archive_ticket_id ticket_id

  def model_changes_for_central
    return @archive_changes if defined?(@archive_changes)
    previous_changes.except(:updated_at)
  end

  def relationship_with_account
    :all_time_sheets
  end

  def belongs_to_ticket?
    workable_type == 'Helpdesk::Ticket'
  end

  def belongs_to_archive_ticket?
    workable_type == 'Helpdesk::ArchiveTicket'
  end
end
