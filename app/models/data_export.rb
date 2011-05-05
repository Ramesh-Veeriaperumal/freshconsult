class DataExport < ActiveRecord::Base
  belongs_to :account
  
  has_one :attachment,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy
  
end
