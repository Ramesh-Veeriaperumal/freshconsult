class Social::TwitterHandle < ActiveRecord::Base
   set_table_name "twitter_handles" 
   belongs_to :product
   belongs_to :user, :class_name =>'User', :foreign_key =>'user_id' 
   
   def screen_name
     user.twitter_id
   end
end