class Freshchat::Account < ActiveRecord::Base
  include RepresentationHelper
  acts_as_api

  api_accessible :central_publish do |fc|
    fc.add :id
    fc.add :account_id, as: :freshdesk_account_id
    fc.add :app_id, as: :freshchat_account_id
    fc.add :api_domain, as: :freshchat_domain
    fc.add :domain, as: :freshchat_account_domain
    fc.add :preferences
    fc.add :enabled
    fc.add proc { |x| x.utc_format(x.created_at) }, as: :created_at
    fc.add proc { |x| x.utc_format(x.updated_at) }, as: :updated_at
  end

  api_accessible :central_publish_destroy do |fc|
    fc.add :app_id, as: :freshchat_account_id
    fc.add :account_id, as: :freshdesk_account_id
  end

  api_accessible :touchstone do |fc|
    fc.add :app_id, as: :freshchat_app_id
    fc.add :domain, as: :freshchat_domain
  end

  def model_changes_for_central
    @model_changes[:freshchat_account_id] = @model_changes.delete(:app_id) if @model_changes.key?(:app_id)
    @model_changes
  end

  def relationship_with_account
    :freshchat_account
  end

  def central_payload_type
    action = [:create, :update, :destroy].find{ |action| 
      transaction_include_action? action }
    "freshchat_account_#{action}"
  end

  def central_publish_worker_class
    'CentralPublishWorker::FreshchatAccountWorker'
  end
end