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

  private

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
