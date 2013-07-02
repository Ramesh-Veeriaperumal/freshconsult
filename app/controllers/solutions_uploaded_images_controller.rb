class SolutionsUploadedImagesController < ApplicationController
  
  include UploadedImagesControllerMethods

  skip_before_filter :check_privilege, :only => [:index]

  def index
    @images = current_account.attachments.gallery_images
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

  private
    
    def cname
      "Image"
    end
end