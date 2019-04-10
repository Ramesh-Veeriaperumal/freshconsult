class ContactFieldChoice < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at].freeze

  acts_as_api

  api_accessible :central_publish do |fc|
    fc.add :id
    fc.add :account_id
    fc.add :contact_field_id
    fc.add :value
    fc.add :position
    DATETIME_FIELDS.each do |key|
      fc.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
    end
  end

  api_accessible :central_publish_destroy do |cf|
    cf.add :id
    cf.add :contact_field_id
    cf.add :account_id
  end

  def self.central_publish_enabled?
    Account.current.contact_field_central_publish_enabled?
  end

  def model_changes_for_central
    @model_changes
  end

  def relationship_with_account
    :contact_field_choices
  end

  def central_publish_worker_class
    'CentralPublishWorker::ContactFieldWorker'
  end
end
