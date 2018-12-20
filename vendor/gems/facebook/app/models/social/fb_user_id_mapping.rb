class Social::FbUserIdMapping < ActiveRecord::Base
  self.table_name =  "social_fb_user_id_mapping"
  self.primary_key = :id
  belongs_to_account
end
