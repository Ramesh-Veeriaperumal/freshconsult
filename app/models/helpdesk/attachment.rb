# encoding: utf-8
require 'mime/types'

class Helpdesk::Attachment < ActiveRecord::Base

  self.table_name =  "helpdesk_attachments"
  self.primary_key = :id

  include Helpdesk::Utils::Attachment
  include Helpdesk::Permission::Attachment
  include Helpdesk::MultiFileAttachment::Util

  attr_accessor :skip_virus_detection

  concerned_with :presenter

  BINARY_TYPE = "application/octet-stream"

  MAX_DIMENSIONS = 16000000

  DRAFT_ATTACHMENTS = ['UserDraft', 'WidgetDraft'].freeze
  ATTACHMENT_EXPIRY = 5.minutes
  ATTACHMENT_REDIRECT_EXPIRY = 10.seconds
  IMAGE_TYPES_WITH_EXIF_DATA = ['image/jpeg', 'image/tiff', 'image/png'].freeze

  NON_THUMBNAIL_RESOURCES = ["Helpdesk::Ticket", "Helpdesk::Note", "Account",
    "Helpdesk::ArchiveTicket", "Helpdesk::ArchiveNote"]

  # Below are list of control characters. Please refer https://en.m.wikipedia.org/wiki/Unicode_control_characters
  CONTROL_CHARACTER_PATTERN = /[\u0000-\u001f]|\u007f|[\u0080-\u009f]|[\u202a-\u202e]/.freeze

  self.table_name =  "helpdesk_attachments"
  belongs_to_account

  belongs_to :attachable, :polymorphic => true

  has_many :shared_attachments, :class_name => 'Helpdesk::SharedAttachment'

  before_save :sanitise_file_name

   has_attached_file :content,
    :storage => :s3,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :path => "data/helpdesk/attachments/#{Rails.env}/:id/:style/:filename",
    :s3_protocol => :https,
    :url => "/:s3_alias_url",
    :s3_host_alias => S3_CONFIG[:bucket_name],
    :s3_host_name => S3_CONFIG[:s3_host_name],
    :s3_options => {
      :http_open_timeout => S3_CONFIG[:http_open_timeout],
      :max_retries => S3_CONFIG[:max_retries],
      # trace & logger helps to debug.
      # :http_wire_trace => true, :logger => CustomLogger.new("#{Rails.root}/log/application.log"),
      :http_read_timeout => S3_CONFIG[:http_read_timeout]
    },
    :s3_server_side_encryption => 'AES256',
    :whiny => false,
    :validate_media_type => false,
    :restricted_characters => /[&$+,\/:;=?@<>\[\]\{\}\|\\\^~%#]/,
    :styles => Proc.new  { |attachment| attachment.instance.attachment_sizes }

  # TODO - please remove this. Refer https://github.com/thoughtbot/paperclip#security-validations
  do_not_validate_attachment_file_type :content

  scope :gallery_images, -> { where(description: 'public', attachable_type: 'Image Upload').order('created_at DESC').limit(20) }


    scope :permissible_drafts, lambda {|user|
      where("attachable_type = ? AND attachable_id = ? ", 'UserDraft', user.id)
    }

    before_save :randomize_filename, :if => :randomize?
    before_post_process :image?, :valid_image?
    before_create :set_content_type
    after_commit :clear_user_avatar_cache, if: :user_attachment?
    after_commit :remove_image_meta_data, if: [:image?, :image_with_exif?, :remove_image_meta_data_feature_enabled?]
    before_save :set_account_id
    validate :virus_in_attachment?, if: :attachment_virus_detection_enabled?

    after_commit :mark_draft_attachment_for_cleanup, on: :create, :if => :draft_attachment?
    after_commit :unmark_draft_attachment_for_cleanup, on: :destroy, :if => :draft_attachment?
    
  alias_attribute :parent_type, :attachable_type

  class << self

    def s3_path(att_id, content_file_name)
      "data/helpdesk/attachments/#{Rails.env}/#{att_id}/original/#{content_file_name}"
    end

    def create_for_3rd_party account, item, attached, i, content_id, mailgun=false
      limit = Account.current.incoming_attachment_limit_25_enabled? ? 25.megabytes : AccountConstants::ATTACHMENT_LIMIT.megabytes
      if attached.is_a?(Hash)
        file_content = attached[:file_content]
        original_filename = attached[:filename]
        content_type = attached[:content_type]
        content_size = attached[:content_size]
        verify_attachment_size = false
      else
        file_content = (attached.is_a? StringIO) ? attached : attached.tempfile
        original_filename = attached.original_filename
        content_type = attached.content_type
        content_size = file_content.size
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
          write_options[:acl] = 'private'
        end

        att = account.attachments.new(attributes)
        if att.save
          att.upload_to_s3(file_content, write_options)
          att
        end
      end
    end

    def decode_token token, account = Account.current
      JWT.decode(token, account.attachment_secret).first.with_indifferent_access
    rescue JWT::ImmatureSignature, JWT::ExpiredSignature, JWT::DecodeError, JWT::VerificationError => e
      Rails.logger.error('JWT decode error')
      Rails.logger.error(e)
      nil
    end

  end

  def upload_to_s3(file, write_options = nil)
    write_options ||= { content_type: content_content_type }
    path = self.class.s3_path(id, content_file_name)
    AwsWrapper::S3.put(S3_CONFIG[:bucket], path, file, write_options.merge(server_side_encryption: 'AES256'))
  end

  def user_attachment?
    self.attachable_type == 'User'
  end

  def s3_permissions
    public_permissions? ? "public-read" : "private"
  end

  def public_permissions?
    description and (description == "logo" || description == "fav_icon" || description == "public" || description == "content_id")
  end

  def set_content_type
    file_ext = File.extname(self.content_file_name).gsub('.','').downcase
    self.content_content_type = BINARY_TYPE if !ATTACHMENT_WHITELIST.keys.include?(file_ext) || !(self.content_content_type.present? && ATTACHMENT_WHITELIST[file_ext] == self.content_content_type.downcase)
  end

  def set_content_dispositon
    self.content.options.merge({:s3_headers => {"Content-Disposition" => "attachment; filename="+self.content_file_name}})
  end

  def attachment_url
    class_string =  self.class
    "#{class_string.to_s.tableize}/#{id}/#{content_file_name}"
  end

  def authenticated_s3_get_url(options={})
    options.reverse_merge!(expires_in: 5.minutes.to_i, secure: true) # PRE-RAILS: s3_host_alias is provided in V1 url_for doc, need to check s3_host_alias: S3_CONFIG[:bucket]. Also when object is stored with server_side_encrypted, it will be automatically encyrypted for presigned_url.
    AwsWrapper::S3.presigned_url(content.bucket_name, content.path, options)
  end

  def image?
    (!(content_content_type =~ /^image.*/).nil?) and (content_file_size < 5242880)
  end

  def image_with_exif?
    IMAGE_TYPES_WITH_EXIF_DATA.include?(content_content_type)
  end

  def remove_image_meta_data_feature_enabled?
    Account.current.launched?(:remove_image_attachment_meta_data)
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
      return {
        :logo => { :geometry => "x50>", :animated => false }
      }
    elsif  self.description == "fav_icon"
      return {
        :fav_icon  => { :geometry => "32x32>", :animated => false }
      }
    else
      return {
        :medium => { :geometry => "127x177>", :animated => false },
        :thumb  => { :geometry => "50x50#", :animated => false }
      }
    end
  end

  def exclude
    [:account_id, :description, :content_updated_at, :attachable_id, :attachable_type]
  end

  def attachment_url_for_api(secure = true, type = :original, expires = 1.day)
    expiry_secure_data = { secure: secure }
    expiry_secure_data.merge!(expires_in: expires.to_i) if expires.present?
    AwsWrapper::S3.presigned_url(content.bucket_name, content.path(valid_size_type(type)), expiry_secure_data)
  end

  def attachment_cdn_url_for_api(secure = true, type = :original, expires = 1.day)
    options = { expires: expires, secure: secure }
    AwsWrapper::CloudFront.url_for(content.path(valid_size_type(type)), options)
  end

  def attachment_url_for_export(secure = true, type = :original, expires = 7.days)
    attachment_url_for_api(secure, type, expires.to_i)
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
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(indent: options[:indent])
    xml.instruct! unless options[:skip_instruct]
    super(builder: xml, skip_instruct: true, except: exclude) do |xml|
      xml.tag!('attachment_url', attachment_url_for_export)
    end
  end

  def expiring_url(style = "original",expiry = 300)
    AwsWrapper::S3.presigned_url(content.bucket_name, content.path(style.to_sym), expires_in: expiry.to_i, secure: true)
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

  def to_io
    io  = open(authenticated_s3_get_url)
    if io
      def io.original_filename
        CGI.unescape(base_uri.path.split('/').last.gsub('%20', ' '))
      end
    end
    io
  end

  def inline_url
    if public_image?
      content.url
    else
      config_env = AppConfig[:attachment][Rails.env]
      "#{config_env[:protocol]}://#{config_env[:domain][PodConfig['CURRENT_POD']]}#{config_env[:port]}#{inline_url_path}"
    end
  end

  def inline_url_path
    "/inline/attachment?token=#{self.encoded_token}"
  end

  def encoded_token
    JWT.encode({ :id => self.id, :domain => Account.current.full_domain, :account_id => Account.current.id }, Account.current.attachment_secret)
  end

  Paperclip.interpolates :filename do |attachment, style|
    attachment.instance.content_file_name
  end

  def inline_image?
    # Inline image will have attachable type as one of these :
    # ArchiveNote::Inline, ArchiveTicket::Inline, Ticket::Inline, Note::Inline
    # Image Upload, Email Notification Image Upload, Forums Image Upload, Templates Image Upload, Tickets Image Upload
    self.attachable_type.include?("Inline") || self.attachable_type.include?("Image Upload")
  end

  def fetch_from_s3
    AwsWrapper::S3Functions.fetch_from_s3(content.path, content.bucket_name, 'twitter')
  end

  def expiry
    self.account.attachment_redirect_expiry_enabled? ? ATTACHMENT_REDIRECT_EXPIRY : ATTACHMENT_EXPIRY
  end

  private

  def set_random_secret
    self.random_secret = SecureRandom.hex(8)
  end

  def sanitise_file_name
    self.content_file_name.gsub!(CONTROL_CHARACTER_PATTERN, '')
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

  def valid_size_type(type)
    attachment_sizes.keys.include?(type) ? type : :original
  end

  def public_image?
    self.attachable_type == "Image Upload" || self.attachable_type == "Forums Image Upload"
  end

  def user_avatar?
    self.attachable_type == "User"
  end

  def logo_or_favicon?
    self.attachable_type == "Portal" && ["logo", "fav_icon"].include?(self.description)
  end

  def randomize?
    return false unless content_file_name_changed? && self.attachable_type
    inline_image? || user_avatar? || logo_or_favicon?
  end

  def randomize_filename
    self.content_file_name = SecureRandom.urlsafe_base64(25) + File.extname(self.content_file_name)
  end

  def remove_image_meta_data
    if content.path.present? && content.bucket_name.present?
      s3_paths = [content.path]
      attachment_sizes.keys.each do |size|
        s3_paths << content.path.gsub('original', size.to_s)
      end
      ImageMetaDataDeleteWorker.perform_async(s3_paths: s3_paths, s3_bucket: content.bucket_name, s3_permissions: s3_permissions)
    end
  end

  def content_file_name_changed?
    return false unless self.changes.keys.include?('content_file_name')
    self.changes["content_file_name"][0] != self.changes["content_file_name"][1]
  end

  def clear_user_avatar_cache
    if attachable && attachable.class.name == "User"
      attachment_sizes.keys.push(:original).each do |profile_size|
        key = ActiveSupport::Cache.expand_cache_key(['v16', 'avatar', profile_size, attachable])
        MemcacheKeys.delete_from_cache(key)
      end
    end
  end

  def virus_in_attachment?
    errors.add(:base, "VIRUS_FOUND") if attachment_has_virus?
  end

  def draft_attachment?
    DRAFT_ATTACHMENTS.include?(attachable_type)
  end

  def mark_draft_attachment_for_cleanup
    mark_for_cleanup(self.id)
  end

  def unmark_draft_for_cleanup
    unmark_for_cleanup(self.id)
  end
end
