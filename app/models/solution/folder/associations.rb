class Solution::Folder < ActiveRecord::Base

  FEATURE_BASED_METHODS = [:articles, :published_articles, :category, :customer_folders]

	belongs_to_account

  belongs_to :category, :class_name => 'Solution::Category'
  
  has_many :articles, :class_name =>'Solution::Article', :dependent => :destroy, :order => :position

  has_many :published_articles, :class_name =>'Solution::Article', :order => "position",
           :conditions => "solution_articles.status = #{Solution::Article::STATUS_KEYS_BY_TOKEN[:published]}"

  has_many :customer_folders , :class_name => 'Solution::CustomerFolder' , :dependent => :destroy

  has_many :activities, :class_name => 'Helpdesk::Activity', :as => 'notable'

end