class CompanyField < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at].freeze

  acts_as_api

  api_accessible :central_publish do |cf|
    cf.add :id
    cf.add :account_id
    cf.add :company_form_id, as: :form_id
    cf.add :name
    cf.add :column_name
    cf.add :label
    cf.add :field_type
    cf.add :position
    cf.add :deleted
    cf.add :required_for_agent
    cf.add :field_options
    DATETIME_FIELDS.each do |key|
      cf.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
    end
  end

  api_accessible :central_publish_destroy do |cf|
    cf.add :id
    cf.add :account_id
  end

  def model_changes_for_central
    @model_changes
  end

  def relationship_with_account
    :company_fields
  end

  def central_publish_worker_class
    'CentralPublishWorker::CompanyFieldWorker'
  end
end
