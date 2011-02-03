class ForumCategory < ActiveRecord::Base
  validates_presence_of :name
  has_many :forums
  belongs_to :account
   
   
   # retrieves forums ordered by position
  def self.find_ordered(account, options = {})
    find :all, options.update(:conditions => {:account_id => account}, :order => 'name')
  end
 end
