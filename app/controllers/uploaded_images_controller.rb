class UploadedImagesController < ApplicationController
  protect_from_forgery :only => [:update, :destroy]
  
  before_filter :except => [:index, :show] do |c| 
    c.requires_permission :manage_knowledgebase
  end
  
  def index
    @images = current_account.attachments.gallery_images;
    respond_to do |format|
      format.html
      format.js
      format.json {
        render :json => @images.map { |i| { :thumb => i.content.url(:medium),
                                            :image => i.content.url,
                                            :title => i.content_file_name } }   
      }
    end
  end
  
  def show
   end
  
   def create    
     @image = Helpdesk::Attachment.new
     @image.description = "public"
     @image.content = params[:image][:uploaded_data]
     @image.attachable_type = "Image Upload"
     @image.account_id = current_account.id
    
    respond_to do |format|
      if @image.content_content_type =~ /image/
        if @image.save
          format.html { render :json => { :filelink => @image.content.url } }
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

  
end