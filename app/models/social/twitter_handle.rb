class Social::TwitterHandle < ActiveRecord::Base
   
  set_table_name "social_twitter_handles" 
  serialize   :search_keys, Array
  belongs_to :product, :class_name => 'EmailConfig'
   
  validates_uniqueness_of :twitter_user_id, :scope => :account_id
  validates_uniqueness_of :product_id
  validates_presence_of :product_id, :twitter_user_id, :account_id,:screen_name
   
  def search_keys_string
    search_keys.blank? ? "" : search_keys.join(",")
  end

end
