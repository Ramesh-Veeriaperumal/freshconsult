class Social::FacebookPage < ActiveRecord::Base
  belongs_to_account
  belongs_to :product
  has_many :fb_posts, :class_name => 'Social::FbPost'
  
  has_many :facebook_streams,
    :foreign_key => :social_id,
    :class_name  => 'Social::FacebookStream'
end
