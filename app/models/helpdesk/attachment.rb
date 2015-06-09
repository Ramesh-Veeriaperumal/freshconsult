# encoding: utf-8
require 'mime/types'

class Helpdesk::Attachment < ActiveRecord::Base

  self.primary_key = :id

  MIME_TYPE_MAPPING = {"ppt" => "application/vnd.ms-powerpoint",
                       "doc" => "application/msword",
                       "xls" => "application/vnd.ms-excel",
                       "pdf" => "application/pdf",
                       "docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                       "xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                       "pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation"}

  MAX_DIMENSIONS = 16000000

  self.table_name =  "helpdesk_attachments"
  belongs_to_account

  belongs_to :attachable, :polymorphic => true

  has_many :shared_attachments, :class_name => 'Helpdesk::SharedAttachment'

   has_attached_file :content,
    :storage => :s3,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :path => "data/helpdesk/attachments/#{Rails.env}/:id/:style/:filename",
    :s3_protocol => :https,
    :url => "/:s3_alias_url",
    :s3_host_alias => S3_CONFIG[:bucket_name],
    :whiny => false,
    :restricted_characters => /[&$+,\/:;=?@<>\[\]\{\}\|\\\^~%#]/,
    :styles => Proc.new  { |attachment| attachment.instance.attachment_sizes }

   scope :gallery_images,
    {
      :conditions => ['description = ? and attachable_type = ?',
      'public', 'Image Upload'],
      :order => "created_at DESC",
      :limit => 20
    }


    before_post_process :image?, :valid_image?
    before_create :set_content_type
    before_save :set_account_id

   def s3_permissions
    public_permissions? ? "public-read" : "private"
   end

   def public_permissions?
    description and (description == "logo" || description == "fav_icon" || description == "public" || description == "content_id")
   end

   def set_content_type
    mime_content_type = lookup_by_extension(File.extname(self.content_file_name).gsub('.',''))
    self.content_content_type = mime_content_type unless mime_content_type.blank?
   end

   def set_content_dispositon
     self.content.options.merge({:s3_headers => {"Content-Disposition" => "attachment; filename="+self.content_file_name}})
  end

  def attachment_url
    class_string =  self.class
    "#{class_string.to_s.tableize}/#{id}/#{content_file_name}"
  end

  def authenticated_s3_get_url(options={})
    options.reverse_merge! :expires => 5.minutes,:s3_host_alias => S3_CONFIG[:bucket], :secure => true
    AwsWrapper::S3Object.url_for content.path, content.bucket_name , options
  end

  def image?
    (!(content_content_type =~ /^image.*/).nil?) and (content_file_size < 5242880)
  end

  def audio?(content_type = /^audio.*/)
     (!(content_content_type =~ content_type).nil?) and (content_file_size < 5242880)
  end

  def mp3?
    audio? /^audio\/(mp3|mpeg)/
  end

  def parent_type
    attachable_type
  end

  def object_type
    :attachable
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

  def exclude
    [:account_id, :description, :content_updated_at, :attachable_id, :attachable_type]
  end

  def attachment_url_for_api(secure=true)
    AwsWrapper::S3Object.url_for(content.path, content.bucket_name, { :expires => 1.days, :secure => secure })
  end

  def as_json(options = {})
    options[:except] = exclude
    options[:methods] = [:attachment_url_for_api]
    json_hash = super(options)
    #json_hash[:attachment_url] = json_hash['attachment'].delete(:attachment_url_for_api)
    attachment_hash = json_hash['attachment']
    attachment_hash[:attachment_url] = attachment_hash.delete(:attachment_url_for_api)
    json_hash['attachment'] = attachment_hash
  end

  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:except => exclude) do |xml|
         xml.tag!("attachment_url", attachment_url_for_api)
     end
   end

  def expiring_url(style = "original",expiry = 300)
    AwsWrapper::S3Object.url_for(content.path(style.to_sym),content.bucket_name,
                                          :expires => expiry.to_i.seconds,
                                          :secure => true)
  end

  def to_liquid
    @helpdesk_attachment_drop ||= Helpdesk::AttachmentDrop.new self
  end

  def valid_image?
    begin
      file_path = content.queued_for_write[:original].path
      dimensions = Paperclip::Geometry.from_file(file_path)
      Rails.logger.info "File Path: #{file_path}"
      Rails.logger.info "Detected Size: #{dimensions.width.to_s} x #{dimensions.height.to_s}"
      # errors.add('Dimensions are higher than Expected.') unless ((dimensions.width * dimensions.height) <= MAX_DIMENSIONS)
      pixel_size = dimensions.width * dimensions.height
      pixel_size <= MAX_DIMENSIONS && (content_content_type == 'image/gif' ? ((content_file_size / pixel_size) < 1000) : true )
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:description => "Error occoured in Validating Images."})
      false
    end
  end

  private

  def set_random_secret
    self.random_secret = SecureRandom.hex(8)
  end

  def lookup_by_extension(extension)
    MIME_TYPE_MAPPING[extension]
  end

  def set_account_id
    if attachable and self.attachable.class.name=="Account"
      self.account_id = self.attachable_id
    elsif attachable
      self.account_id = attachable.account_id
    end
  end

end
