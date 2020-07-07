class Helpdesk::Source < Helpdesk::Choice
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at].freeze

  acts_as_api

  api_accessible :central_publish do |br|
    br.add :id
    br.add :account_choice_id, as: :source_id
    br.add :name
    br.add :account_id
    br.add :position
    br.add :deleted
    br.add :default
    br.add :type, as: :model_type
    DATETIME_FIELDS.each do |key|
      br.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
    end
  end

  def model_changes_for_central
    previous_changes
  end

  def relationship_with_account
    :helpdesk_sources
  end

  def central_payload_type
    action = [:create, :update].find { |act| transaction_include_action? act }
    "ticket_source_#{action}"
  end

  def central_publish_worker_class
    'CentralPublishWorker::TicketFieldWorker'
  end
end
