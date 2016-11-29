# encoding: utf-8
require 'mime/types'

class Helpdesk::Attachment < ActiveRecord::Base

  self.table_name =  "helpdesk_attachments"
  self.primary_key = :id

  include Helpdesk::Utils::Attachment

  BINARY_TYPE = "application/octet-stream"

  MAX_DIMENSIONS = 16000000

  NON_THUMBNAIL_RESOURCES = ["Helpdesk::Ticket", "Helpdesk::Note", "Account", 
    "Helpdesk::ArchiveTicket", "Helpdesk::ArchiveNote"]

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
    :s3_host_name => S3_CONFIG[:s3_host_name],
    :s3_server_side_encryption => 'AES256',
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


    before_save :randomize_filename, :if => :randomize?
    before_post_process :image?, :valid_image?
    before_create :set_content_type
    before_save :set_account_id

  alias_attribute :parent_type, :attachable_type

  class << self

    def s3_path(att_id, content_file_name)
      "data/helpdesk/attachments/#{Rails.env}/#{att_id}/original/#{content_file_name}"
    end

    def create_for_3rd_party account, item, attached, i, content_id, mailgun=false, social=false
      limit = mailgun ? HelpdeskAttachable::MAILGUN_MAX_ATTACHMENT_SIZE : 
                        HelpdeskAttachable::MAX_ATTACHMENT_SIZE
      if attached.is_a?(Hash)
        file_content = attached[:file_content] 
        original_filename = attached[:filename]
        content_type = attached[:content_type] 
        content_size = attached[:content_size] 
        verify_attachment_size = false 
      else
        file_content = attached.tempfile
        original_filename = attached.original_filename
        content_type = attached.content_type
        content_size = attached.tempfile.size
        verify_attachment_size = true
      end

      unless verify_attachment_size && item.validate_attachment_size(
        {:content => file_content},{:attachment_limit => limit })
        filename = self.new.utf8_name original_filename,
                             "attachment-#{i+1}"
        attributes = { :content_file_name => filename,
                       :content_content_type => content_type,
                       :content_file_size => content_size.to_i
                      }
        write_options = { :content_type => content_type }
        if content_id
          model = item.is_a?(Helpdesk::Ticket) ? "Ticket" : "Note"
          attributes.merge!({:description => "content_id", :attachable_type => "#{model}::Inline"})
          write_options.merge!({ :acl => attachment_permissions(social) })
        end

        att = account.attachments.new(attributes)
        if att.save
          path = s3_path(att.id, att.content_file_name)
          AwsWrapper::S3Object.store(path, 
                                     file_content, 
                                     S3_CONFIG[:bucket], 
                                     write_options)
          att
        end
      end
    end

    def decode_token token, account = Account.current
      JWT.decode(token, account.attachment_secret).first.with_indifferent_access
    end

    def attachment_permissions social
      !social && Account.current.features_included?(:inline_images_with_one_hop) ? "private" : "public-read"
    end
  end

  def s3_permissions
    public_permissions? ? "public-read" : "private"
  end

  def public_permissions?
    description and (description == "logo" || description == "fav_icon" || description == "public" || description == "content_id")
  end

  def set_content_type
    file_ext = File.extname(self.content_file_name).gsub('.','').downcase
    self.content_content_type = BINARY_TYPE if !ATTACHMENT_WHITELIST.keys.include?(file_ext) || ATTACHMENT_WHITELIST[file_ext] != self.content_content_type.downcase
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

  def object_type
    :attachable
  end

  def has_thumbnail?
    !(NON_THUMBNAIL_RESOURCES.include?(attachable_type))
  end

  def attachment_sizes
   if self.description == "logo"
      return {:logo => "x50>"}
   elsif  self.description == "fav_icon"
      return {:fav_icon  => "32x32>" }
   else
      return {:medium => "127x177>",:thumb  => "50x50#" }
    end
  end

  def exclude
    [:account_id, :description, :content_updated_at, :attachable_id, :attachable_type]
  end

  def attachment_url_for_api(secure=true)
    AwsWrapper::S3Object.url_for(content.path, content.bucket_name, { :expires => 1.days, :secure => true })
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

  def to_jq_upload
    {
      "id"          => self.id,
      "name"        => content_file_name,
      "size"        => content_file_size,
      "url"         => Rails.application.routes.url_helpers.helpdesk_attachment_path(self),
      "delete_url"  => Rails.application.routes.url_helpers.delete_attachment_helpdesk_attachment_path(self),
      "delete_type" => "DELETE" 
    }
  end

  def inline_url
    if !public_image? && Account.current.features_included?(:inline_images_with_one_hop)
      config_env = AppConfig[:attachment][Rails.env]
      "#{config_env[:protocol]}://#{config_env[:domain][PodConfig['CURRENT_POD']]}#{config_env[:port]}#{inline_url_path}"
    else
      self.content.url
    end
  end

  def inline_url_path
    "/inline/attachment?token=#{self.encoded_token}"
  end

  def encoded_token
    JWT.encode({ :id => self.id, :domain => Account.current.full_domain }, Account.current.attachment_secret)
  end

  Paperclip.interpolates :filename do |attachment, style|
    attachment.instance.content_file_name
  end

  private

  def set_random_secret
    self.random_secret = SecureRandom.hex(8)
  end

  def set_account_id
    unless self.account_id
      if attachable and self.attachable.class.name=="Account"
        self.account_id = self.attachable_id
      elsif attachable
        self.account_id = attachable.account_id
      end
    end
  end

  def public_image?
    self.attachable_type == "Image Upload" || self.attachable_type == "Forums Image Upload"
  end

  def inline_image?
    # Inline image will have attachable type as one of these :
    # ArchiveNote::Inline, ArchiveTicket::Inline, Ticket::Inline, Note::Inline
    # Image Upload, Email Notification Image Upload, Forums Image Upload, Templates Image Upload, Tickets Image Upload
    self.attachable_type.include?("Inline") || self.attachable_type.include?("Image Upload")
  end

  def user_avatar?
    self.attachable_type == "User"
  end

  def logo_or_favicon?
    self.attachable_type == "Portal" && ["logo", "fav_icon"].include?(self.description)
  end

  def randomize?
    return false unless self.attachable_type
    inline_image? || user_avatar? || logo_or_favicon?
  end

  def randomize_filename
    self.content_file_name = SecureRandom.urlsafe_base64(25) + File.extname(self.content_file_name)
  end

end
