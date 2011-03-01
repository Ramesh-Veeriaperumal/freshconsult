class Helpdesk::Attachment < ActiveRecord::Base

  set_table_name "helpdesk_attachments"

  belongs_to :attachable, :polymorphic => true

  has_attached_file :content, 
    :storage => :s3,
    :s3_credentials => "#{RAILS_ROOT}/config/s3.yml",
    :path => "/data/helpdesk/attachments/:id/:style/:filename",
    :url => "/:class/:id",
    :styles => Proc.new  { |attachment| attachment.instance.attachment_sizes }
   #:bucket => 'fdesk-attachments'
    
  before_post_process :image?
  
 
  
    
  def image?
    !(content_content_type =~ /^image.*/).nil?
  end
  
  
  
  def attachment_sizes
   if self.description == "logo"
      return {:logo => "x50>"}
   elsif  self.description == "fav_icon"
      return {:fav_icon  => "16x16>" }
   else
      return {:medium => "127x177>",:thumb  => "50x50#" }
    end
  end

end
