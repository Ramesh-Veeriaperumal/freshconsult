class Admin::TwitterHandle < ActiveRecord::Base
   set_table_name "admin_twitter_handles" 
   
   belongs_to :account
   belongs_to :user, :class_name =>'User', :foreign_key =>'user_id' 
   belongs_to :group, :foreign_key =>'group_id'
   
   def screen_name
     user.twitter_id
   end
end
