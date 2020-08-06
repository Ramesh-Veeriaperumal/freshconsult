class Authorization < ActiveRecord::Base
  
  self.primary_key = :id
  
  belongs_to_account

  belongs_to :user
  validates_presence_of :user_id, :uid, :provider, :account_id
  validates_uniqueness_of :uid, :scope => [:provider , :account_id]

  scope :authorizations_without_freshid, -> { where(['provider != ?', Freshid::Constants::FRESHID_PROVIDER]) }

  def self.find_from_hash(hash,account_id)
    find_by_provider_and_uid_and_account_id(hash['provider'], hash['uid'],account_id)
  end

  def notify_uuid_change_to_user!
    user.notify_uuid_change_to_user!
  end

end
