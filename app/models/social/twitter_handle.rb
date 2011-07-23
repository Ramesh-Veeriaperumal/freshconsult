class Social::TwitterHandle < ActiveRecord::Base
   
   set_table_name "social_twitter_handles" 
   serialize   :search_keys, Array
   belongs_to :product, :class_name => 'EmailConfig'
   belongs_to :user
   
   def screen_name
     user.twitter_id
   end

end
