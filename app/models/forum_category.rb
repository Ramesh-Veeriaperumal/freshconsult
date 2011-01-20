class ForumCategory < ActiveRecord::Base
  belongs_to :product
  has_many :forums
end
