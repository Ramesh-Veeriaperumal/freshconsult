class Admin::TwitterSearchKey < ActiveRecord::Base
  set_table_name "admin_twitter_search_keys" 
   belongs_to :account
   belongs_to :twitter_handle , :class_name =>'Admin::TwitterHandle' 
end
