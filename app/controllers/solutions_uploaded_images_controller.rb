class SolutionsUploadedImagesController < ApplicationController
  
  include UploadedImagesControllerMethods

  def index
    @images = current_account.attachments.gallery_images
      # For Froala we need :thumb, :image, :title
      render :json => @images.map { |i| { :thumb => i.content.url(:medium),
                                          :url => i.content.url,
                                          :image => i.content.url, # For froala
                                          :title => i.content_file_name,
                                          :attachment_id => i.id} }
  end

  private
    
    def cname
      "Image"
    end
end