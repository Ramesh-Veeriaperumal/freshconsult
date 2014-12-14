require 'spec_helper.rb'

SAMPLE_FILES = ["/files/ff-notification-icon-2x.png",
  "/files/favicon.ico",
  "/files/facebook.png"
]

describe SolutionsUploadedImagesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  it "should upload an attachment in create action" do
    post :create, { :image => { :uploaded_data => fixture_file_upload(SAMPLE_FILES.first, 'image/png', :binary) } }
    response.status.should eql(200)
    JSON.parse(response.body)['filelink'].should =~ /#{File.basename(SAMPLE_FILES.first)}/
    JSON.parse(response.body)['filelink'].should =~ /^https:\/\//
  end

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