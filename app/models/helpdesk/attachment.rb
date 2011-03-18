class Helpdesk::Attachment < ActiveRecord::Base

  set_table_name "helpdesk_attachments"

  belongs_to :attachable, :polymorphic => true
  has_attached_file  :content, 
                    :storage => :s3, 
                    :s3_credentials =>"#{RAILS_ROOT}/config/s3.yml", 
                    :url => ":s3_alias_url",
                    :s3_host_alias => "cdn.freshdesk.com",
                    :path => lambda { |attachment| ":id_partition/:filename" },
                    :styles => Proc.new  { |attachment| attachment.instance.attachment_sizes }
  
 
  
    #before_validation_on_create :set_random_secret
    before_post_process :image?
  
  
  def attachment_url
    class_string =  self.class
    "#{class_string.to_s.tableize}/#{id}/#{content_file_name}"
  end
  
  def authenticated_s3_get_url(options={})
    options.reverse_merge! :expires_in => 1.minutes,:s3_host_alias => "cdn.freshdesk.com"
    AWS::S3::S3Object.url_for content.path, content.bucket_name , options
  end
 
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
  
  private
  
  def set_random_secret
    self.random_secret = ActiveSupport::SecureRandom.hex(8)
  end
  

end
