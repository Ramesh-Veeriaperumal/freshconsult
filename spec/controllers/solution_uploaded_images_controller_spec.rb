require 'spec_helper.rb'

describe SolutionsUploadedImagesController do

  include_examples "UploadImages"

  it "should list all the images created in index action" do
    @account.attachments.each &:destroy
    attachment_names = []
    SAMPLE_FILES.each do |file_path|
      file_path = "#{Rails.root}/spec/fixtures#{file_path}"
      file = File.new(file_path)
      attachment = @account.attachments.build({
        :content => file,
      })
      attachment.description = "public"
      attachment.attachable_type = "Image Upload"
      attachment.save
      attachment_names << File.basename(file_path)
    end

    get :index, :format => 'json'
    response.status.should eql(200)

    response_array = JSON.parse(response.body)
    response_array.each do |attachment| 
      attachment.should have_key 'image'
      attachment.should have_key 'thumb'
      attachment.should have_key 'title'
    end

    titles = response_array.map{ |attachment| attachment['title'] }
    attachment_names.each do |name|
      titles.should include name
    end
  end

end