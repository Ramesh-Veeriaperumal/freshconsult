class Helpdesk::Attachment < ActiveRecord::Base

  set_table_name "helpdesk_attachments"

  belongs_to :attachable, :polymorphic => true

  has_attached_file :content, 
    :storage => :s3,
    :s3_credentials => "#{RAILS_ROOT}/config/s3.yml",
    :path => "/data/helpdesk/attachments/:id/:filename",
    :url => "/:class/:id",
    :styles => { :thumb => "50x50>" }
    #:bucket => 'fdesk-attachments'
    
  before_post_process :image?
    
  def image?
    !(content_content_type =~ /^image.*/).nil?
  end

end
