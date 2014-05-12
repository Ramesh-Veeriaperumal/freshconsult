class Social::TwitterHandle < ActiveRecord::Base

  belongs_to_account
  belongs_to :product

  has_one :avatar,
    :as         => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent  => :destroy

  has_many :twitter_streams,
    :foreign_key => :social_id,
    :class_name  => 'Social::TwitterStream'

end
