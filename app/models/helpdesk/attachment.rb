class Helpdesk::Attachment < ActiveRecord::Base

  set_table_name "helpdesk_attachments"

  belongs_to :attachable, :polymorphic => true

  has_attached_file :content, 
    :path => ":rails_root/data/helpdesk/attachments/:id/:filename",
    :url => "/:class/:id"


end
