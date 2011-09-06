class Social::FacebookPage < ActiveRecord::Base
  set_table_name "social_facebook_pages" 
  belongs_to :account 
  belongs_to :product, :class_name => 'EmailConfig'
   
end
