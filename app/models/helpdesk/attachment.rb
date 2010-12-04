class Helpdesk::Attachment < ActiveRecord::Base

  set_table_name "helpdesk_attachments"

  belongs_to :attachable, :polymorphic => true

  has_attached_file :content, 
    :storage => :s3,
    :s3_credentials => "#{RAILS_ROOT}/config/s3.yml",
    :path => "/data/helpdesk/attachments/:id/:filename",
    :url => "/:class/:id"
    #:bucket => 'fdesk-attachments'

end
