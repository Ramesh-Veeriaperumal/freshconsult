class Social::FacebookPage < ActiveRecord::Base
  belongs_to_account
  belongs_to :product
  has_many :fb_posts, :class_name => 'Social::FbPost'
end
