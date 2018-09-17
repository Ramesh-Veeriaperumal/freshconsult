class Social::FacebookPage < ActiveRecord::Base
  include RepresentationHelper
  acts_as_api

  api_accessible :central_publish do |t|
    t.add :id
    t.add :account_id
    t.add :page_name
    t.add :reauth_required
    t.add :realtime_messaging
    t.add proc { |page| page.profile_id.to_s }, as: :profile_id
    t.add proc { |page| page.page_id.to_s }, as: :page_id
    t.add proc { |page| page.utc_format(page.created_at) }, as: :created_at
    t.add proc { |page| page.utc_format(page.updated_at) }, as: :updated_at
  end

  def relationship_with_account
    :facebook_pages
  end

  def event_info(event)
    { :pod => ChannelFrameworkConfig['pod'] }
  end
  
end
