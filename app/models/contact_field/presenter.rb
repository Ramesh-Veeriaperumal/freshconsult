class ContactField < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at].freeze

  acts_as_api

  api_accessible :central_publish do |cf|
    cf.add :id
    cf.add :account_id
    cf.add :contact_form_id, as: :form_id
    cf.add :name
    cf.add :column_name
    cf.add :label
    cf.add :label_in_portal
    cf.add :field_type
    cf.add :position
    cf.add :deleted
    cf.add :required_for_agent
    cf.add :visible_in_portal
    cf.add :editable_in_portal
    cf.add :editable_in_signup
    cf.add :required_in_portal
    cf.add :field_options
    DATETIME_FIELDS.each do |key|
      cf.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
    end
  end

  api_accessible :central_publish_destroy do |cf|
    cf.add :id
    cf.add :account_id
  end

  def self.central_publish_enabled?
    Account.current.contact_field_central_publish_enabled?
  end

  def model_changes_for_central
    @model_changes
  end

  def relationship_with_account
    :contact_fields
  end

  def central_publish_worker_class
    'CentralPublishWorker::ContactFieldWorker'
  end
end
