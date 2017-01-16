module UploadedImagesControllerMethods

  WHITELISTED_INLINE_IMAGE_FORMAT = ["jpeg","jpg","png","tif","tiff",'gif']
  INVERTED_MIME_TYPES = Rack::Mime::MIME_TYPES.invert

  def self.included(base)
    base.send :before_filter, :check_anonymous_user, :only => [:create]
  end

  def create
    @image = current_account.attachments.build({
      :description      => !public_upload? && one_hop? ? "private" : "public",
      :content          => params[:image][:uploaded_data],
      :attachable_type  => "#{cname} Upload"
    })

    respond_to do |format|
      format.html do
        type = params[:image][:uploaded_data].content_type
        render :json => (whitelisted_image?(type) && check_image? && @image.save) ? success_response : error_response
      end
    end
  end

  def create_file
    splited_dataURI = splitBase64(params[:dataURI])

    data_f = StringIO.new(Base64.decode64(splited_dataURI[:data]))
    data_f.class_eval do
       attr_accessor :content_type, :original_filename
    end
    data_f.content_type = splited_dataURI[:type]
    data_f.original_filename = "blob" + CGI.escapeHTML(params["_uniquekey"]) + "." + splited_dataURI[:extension]
   
    @image = current_account.attachments.build({
      :description      => !public_upload? && one_hop? ? "private" : "public",
      :content          => data_f,
      :attachable_type  => "#{cname} Upload"
    })

    respond_to do |format|
      format.json do
        type = data_f.content_type
        render :json => (whitelisted_image?(type) && @image.save) ? success_response : error_response
      end
    end
  end

  private
    def splitBase64(uri)
      if uri.match(%r{^data:(.*?);(.*?),(.*)$})
        return {
          type:      $1, # "image/png"
          encoder:   $2, # "base64"
          data:      $3, # data string
          extension: $1.split('/')[1] # "png"
          }
      end
    end

    def success_response
      # :link For Froala
      { :link => @image.inline_url, :filelink => @image.inline_url, :fileid => @image.id, :uniquekey => CGI.escapeHTML(params["_uniquekey"]) }
    end

    def error_response
      { :error => @image.errors.blank? ? [] : @image.errors.full_messages.to_sentence, :uniquekey => CGI.escapeHTML(params["_uniquekey"]) }
    end

    def check_image?
      unless @image.image? && @image.valid_image?
        @image.errors.clear
        @image.errors.add('ERROR :', 'Image Dimensions are larger than Expected, Please send them as attachments instead')
        false
      else
        true
      end
    end

    def one_hop?
      current_account.features_included?(:inline_images_with_one_hop)
    end

    def public_upload?
      cname == "Image" || cname == "Forums Image"
    end

    def whitelisted_image?(content_type)
      ext = INVERTED_MIME_TYPES[content_type].gsub('.', '')
      WHITELISTED_INLINE_IMAGE_FORMAT.include?(ext)
    end

end
