class ForumCategory < ActiveRecord::Base
  validates_presence_of :name,:account
  has_many :forums, :dependent => :destroy
  belongs_to :account
   
   
   # retrieves forums ordered by position
  def self.find_ordered(account, options = {})
    find :all, options.update(:conditions => {:account_id => account}, :order => 'name')
  end
  
  
 end
