class DashboardAnnouncement < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :central_publish do |da|
    da.add :id
    da.add :announcement_text
    da.add :active
    da.add :account_id
    da.add :dashboard_id
    da.add :user_id
    da.add proc { |x| x.utc_format(x.created_at) }, as: :created_at
    da.add proc { |x| x.utc_format(x.updated_at) }, as: :updated_at
  end

  api_accessible :central_publish_associations do |t|
    t.add :dashboard, template: :central_publish
  end

  def central_payload_type
    current_action = [:create].find { |action| transaction_include_action? action }
    "dashboard_announcement_#{current_action}"
  end

  def relationship_with_account
    'dashboard_announcements'
  end
end
