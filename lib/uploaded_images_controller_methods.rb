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
        render :json => (@image.image? && @image.save) ?  success_response : error_response 
      end
    end
  end

  private

    def check_anonymous_user
      access_denied unless logged_in?
    end

    def success_response
      { :filelink => AwsWrapper::S3Object.url_for(@image.content.path,@image.content.bucket_name, :secure => true),
        :fileid => @image.id, :uniquekey => params["_uniquekey"] }
    end

    def error_response
     { :error => @image.errors.blank? ? [] : @image.errors.full_messages.to_sentence, :uniquekey => params["_uniquekey"] }
    end
end