require 'spec_helper.rb'

SAMPLE_FILES = ["#{RAILS_ROOT}/public/images/ff-notification-icon-2x.png",
  "#{RAILS_ROOT}/public/images/favicon.ico",
  "#{RAILS_ROOT}/public/images/facebook_32.png"
]

describe SolutionsUploadedImagesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  it "should upload an attachment in create action" do
    file = File.new(SAMPLE_FILES.first)
    post :create, { :image => { :uploaded_data => file } }
    response.status.should eql('200 OK')
    JSON.parse(response.body)['filelink'].should =~ /#{File.basename(SAMPLE_FILES.first)}/
    JSON.parse(response.body)['filelink'].should =~ /^https:\/\//
  end

  it "should list all the images created in index action" do
    @account.attachments.each &:destroy
    attachment_names = []
    SAMPLE_FILES.each do |file_path|
      file = File.new(file_path)
      @account.attachments.create({
        :description => "public",
        :content => file,
        :attachable_type => "Image Upload"
      })
      attachment_names << File.basename(file_path)
    end

    get :index, :format => 'json'
    response.status.should eql('200 OK')

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