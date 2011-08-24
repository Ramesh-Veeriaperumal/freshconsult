class Social::TwitterHandle < ActiveRecord::Base
   
  set_table_name "social_twitter_handles" 
  serialize   :search_keys, Array
  belongs_to :product, :class_name => 'EmailConfig'
  belongs_to :account 
  
  before_validation :check_product_id
  before_create :add_default_search
  
   
  validates_uniqueness_of :twitter_user_id, :scope => :account_id
  validates_presence_of :product_id, :twitter_user_id, :account_id,:screen_name
   
  def search_keys_string
    search_keys.blank? ? "" : search_keys.join(",")
  end
  
  def add_default_search
    if search_keys.blank?
      searches = Array.new
      searches.push("@#{screen_name}")
      self.search_keys = searches
    end
  end
  
  def check_product_id
    self.product_id ||= Account.current.primary_email_config.id 
  end

end
