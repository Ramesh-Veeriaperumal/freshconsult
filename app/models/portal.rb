class Portal < ActiveRecord::Base
  serialize :preferences, Hash
  
  has_one :logo,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :conditions => ['description = ?', 'logo' ],
    :dependent => :destroy
  
  has_one :fav_icon,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :conditions => ['description = ?', 'fav_icon' ],
    :dependent => :destroy

  belongs_to :account
  belongs_to :product, :class_name => 'EmailConfig'
end
