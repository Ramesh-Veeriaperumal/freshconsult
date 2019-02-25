class Helpdesk::PicklistValue < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at].freeze

  acts_as_api

  api_accessible :central_publish do |br|
    br.add :id
    br.add :pickable_id
    br.add :position
    br.add :value
    br.add :account_id
    br.add :picklist_id
    DATETIME_FIELDS.each do |key|
      br.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
    end
  end

  api_accessible :central_publish_associations do |t|
    t.add :pickable_payload, as: :pickable
  end

  api_accessible :central_publish_destroy do |br|
    br.add :id
    br.add :pickable_id
    br.add :account_id
  end

  def relationship_with_account
    :picklist_values
  end

  def model_changes_for_central
    @model_changes
  end

  def central_publish_worker_class
    'CentralPublishWorker::TicketFieldWorker'
  end

  # naming as this because pickable is an association of picklist value
  def pickable_payload
    { id: pickable_id, _model: pickable_type }
  end
end
