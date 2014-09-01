class Social::TwitterHandle < ActiveRecord::Base

  validates_uniqueness_of :twitter_user_id, :scope => :account_id
  validates_presence_of :twitter_user_id, :account_id, :screen_name

end
