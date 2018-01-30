class User < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :central_publish do |u|
    u.add :id
    u.add :name
    u.add :email
    u.add :last_login_at
    u.add :current_login_at
    u.add :last_login_ip
    u.add :current_login_ip
    u.add :login_count
    u.add :failed_login_count
    u.add proc { |x| x.utc_format(x.created_at) }, as: :created_at
    u.add proc { |x| x.utc_format(x.updated_at) }, as: :updated_at
    u.add :account_id
    u.add :active
    u.add :customer_id
    u.add :job_title
    u.add :second_email
    u.add :phone
    u.add :mobile
    u.add :twitter_id
    u.add :description
    u.add :time_zone
    u.add :posts_count
    u.add :last_seen_at
    u.add :deleted
    u.add :user_role
    u.add :delta
    u.add :import_id
    u.add :fb_profile_id
    u.add :language
    u.add :blocked
    u.add proc { |x| x.utc_format(x.blocked_at) }, as: :blocked_at
    u.add :address
    u.add proc { |x| x.utc_format(x.deleted_at) }, as: :deleted_at
    u.add :whitelisted
    u.add :external_id
    u.add :preferences
    u.add :helpdesk_agent
    u.add :privileges
    u.add :extn
    u.add :parent_id
    u.add :unique_external_id
  end
end