class Helpdesk::TicketStatus < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at].freeze

  acts_as_api

  api_accessible :central_publish do |br|
    br.add :id
    br.add :status_id
    br.add :name
    br.add :customer_display_name
    br.add :stop_sla_timer
    br.add :deleted
    br.add :is_default
    br.add :account_id
    br.add :ticket_field_id
    br.add :position
    DATETIME_FIELDS.each do |key|
      br.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
    end
  end

  def relationship_with_account
    :ticket_statuses
  end

  def model_changes_for_central
    @model_changes
  end

  def central_publish_worker_class
    'CentralPublishWorker::TicketFieldWorker'
  end
end
