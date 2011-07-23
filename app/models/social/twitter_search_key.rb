class Social::TwitterSearchKey < ActiveRecord::Base
  
   set_table_name "social_twitter_search_keys" 
   belongs_to :account
   belongs_to :twitter_handle , :class_name =>'Social::TwitterHandle'
   
end
