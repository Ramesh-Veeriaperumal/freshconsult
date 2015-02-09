module UploadedImagesControllerMethods

  def self.included(base)
    base.send :before_filter, :check_anonymous_user, :only => [:create]
  end

  def create
    @image = current_account.attachments.build({
      :description => "public",
      :content => params[:image][:uploaded_data],
      :attachable_type => "#{cname} Upload"
    })

    respond_to do |format|
      format.html do
        render :json => (check_image? && @image.save) ? success_response : error_response
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
    data_f.original_filename = "blob" + params["_uniquekey"] + "." + splited_dataURI[:extension]
   
    @image = current_account.attachments.build({
      :description => "public",
      :content => data_f,
      :attachable_type => "#{cname} Upload"
    })

    respond_to do |format|
      format.json do
        render :json => (@image.save) ? success_response : error_response
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

    def check_anonymous_user
      access_denied unless logged_in?
    end

    def success_response
      { :filelink => @image.content.url, :fileid => @image.id, :uniquekey => params["_uniquekey"] }
    end

    def error_response
      { :error => @image.errors.blank? ? [] : @image.errors.full_messages.to_sentence, :uniquekey => params["_uniquekey"] }
    end

    def check_image?
      unless @image.image? && @image.valid_image?
        @image.errors.clear
        @image.errors.add('ERROR :', 'Image Dimensions are larger than Expected, Please send them as attachments instead')
        return false
      else
        return true
      end
    end

end
