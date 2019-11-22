class Freshcaller::Account < ActiveRecord::Base
  include RepresentationHelper
  acts_as_api

  api_accessible :api do |fc|
    fc.add :domain
    fc.add :enabled    
  end

  api_accessible :central_publish do |fc|
    fc.add :id
    fc.add :account_id, as: :freshdesk_account_id
    fc.add :freshcaller_account_id
    fc.add :domain, as: :freshcaller_domain
    fc.add :enabled
    fc.add proc { |x| x.utc_format(x.created_at) }, as: :created_at
    fc.add proc { |x| x.utc_format(x.updated_at) }, as: :updated_at
  end

  api_accessible :central_publish_destroy do |fc|
    fc.add :freshcaller_account_id
    fc.add :account_id, as: :freshdesk_account_id
  end

  def relationship_with_account
    :freshcaller_account
  end

  def central_payload_type
    action = [:create, :destroy, :update].find { |action|
      transaction_include_action? action }
    "freshcaller_account_#{action}"
  end

  def central_publish_worker_class
    'CentralPublishWorker::FreshcallerAccountWorker'
  end
end
