class Authorization < ActiveRecord::Base
  
  belongs_to :user
  validates_presence_of :user_id, :uid, :provider, :account_id
  validates_uniqueness_of :uid, :scope => [:provider , :account_id]
  
  def self.find_from_hash(hash,account_id)
    find_by_provider_and_uid_and_account_id(hash['provider'], hash['uid'],account_id)
  end

  
  
end
