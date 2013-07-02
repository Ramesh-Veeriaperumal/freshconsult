module UploadedImagesControllerMethods

  def self.included(base)
    base.send :before_filter, :check_anonymous_user, :only => [:create]
  end

  def create    
    @image = current_account.attachments.new
    @image.description = "public"
    @image.content = params[:image][:uploaded_data]
    @image.attachable_type = "#{cname} Upload"

    respond_to do |format|
      if @image.image?
        if @image.save
          format.html { render :json => { :filelink => @image.content.url, :fileid => @image.id } }
          format.json { render :json => { :filelink => @image.content.url } }
          format.xml  
          format.js do
            responds_to_parent do
              render :update do |page|
                page << "ImageDialog.ts_insert_image('#{@image.content.url}', '#{@image.content_file_name}');"
              end
            end
          end
        else
          format.html
          format.xml  
          format.js do
            responds_to_parent do
              render :update do |page|
                page.alert('sorry, error uploading image')
              end
            end
          end
        end
      else
        format.html { render :json => {}}  
        format.xml
        format.json { render :json => {}}  
        format.js do
          responds_to_parent do
            render :update do |page|
              page.alert('sorry, please provide a valid image file')
            end
          end
        end
      end
    end
  end

  private

    def check_anonymous_user
      access_denied unless logged_in?
    end
end