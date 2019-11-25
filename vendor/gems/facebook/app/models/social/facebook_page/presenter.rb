class Social::FacebookPage < ActiveRecord::Base
  include CentralLib::Util
  include RepresentationHelper
  acts_as_api

  api_accessible :central_publish do |t|
    t.add :id
    t.add :account_id
    t.add :page_name
    t.add :reauth_required
    t.add :realtime_messaging
    t.add proc { |x| x.encrypt_for_central(x.access_token, 'facebook') }, as: :access_token
    t.add proc { |x| x.encrypt_for_central(x.page_token, 'facebook') }, as: :page_token
    t.add proc { |x| x.encryption_key_name('facebook') }, as: :encryption_key_name
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

  def model_changes_for_central
    @model_changes[:access_token].map! { |x| encrypt_for_central(x, 'facebook') } if @model_changes[:access_token].present?
    @model_changes[:page_token].map! { |x| encrypt_for_central(x, 'facebook') } if @model_changes[:page_token].present?
    @model_changes
  end
  
end
