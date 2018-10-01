class Social::TwitterHandle < ActiveRecord::Base
  include RepresentationHelper
  acts_as_api

  api_accessible :central_publish do |t|
    t.add :id
    t.add :account_id
    t.add proc { |x| x.twitter_user_id.to_s }, as: :twitter_user_id
    t.add proc { |x| x.utc_format(x.created_at) }, as: :created_at
    t.add proc { |x| x.utc_format(x.updated_at) }, as: :updated_at
    t.add :screen_name
    t.add proc { |x| x.encrypt_for_central(x.access_token, 'twitter') }, as: :access_token
    t.add proc { |x| x.encrypt_for_central(x.access_secret, 'twitter') }, as: :access_secret
    t.add :state
    t.add proc {|x| x.encryption_key_name('twitter')}, as: :encryption_key_name
  end

  def model_changes_for_central
    previous_changes = self.previous_changes
    return if previous_changes.blank?
    attributes_to_encrypt = %w[access_secret access_token]
    attributes_to_encrypt.each do |attribute|
      changes = previous_changes.try(:[], attribute)
      if changes.present?
        changes.map! { |x| encrypt_for_central(x) }
        previous_changes[attribute] = changes
      end
    end
    previous_changes
  end

  def relationship_with_account
    :twitter_handles
  end

  def self.central_publish_enabled?
    Account.current.twitter_handle_publisher_enabled?
  end
  
end
