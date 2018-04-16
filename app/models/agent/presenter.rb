class Agent < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at, :active_since, :last_active_at]

  acts_as_api

  api_accessible :central_publish do |s|
    s.add :id
    s.add :user_id
    s.add :signature
    s.add :ticket_permission
    s.add :occasional
    s.add :google_viewer_id
    s.add :signature_html
    s.add :points
    s.add :scoreboard_level_id
    s.add :account_id
    s.add :available
    DATETIME_FIELDS.each do |key|
      s.add proc { |d| d.utc_format(d.safe_send(key)) }, as: key
    end
  end

  def self.central_publish_enabled?
    Account.current.audit_logs_central_publish_enabled?
  end

  def model_changes_for_central
    self.previous_changes
  end

  def relationship_with_account
    "agents"
  end

  def central_publish_worker_class
    "CentralPublishWorker::UserWorker"
  end
end
