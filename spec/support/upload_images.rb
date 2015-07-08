SAMPLE_FILES = ["/files/ff-notification-icon-2x.png",
  "/files/favicon.ico",
  "/files/facebook.png"
]

SAMPLE_DATA_URL = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQIHWNgAAIAAAUAAY27m/MAAAAASUVORK5CYII="

RSpec.shared_examples "UploadImages" do

	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:each) do
		login_admin
	end

	it "should upload an attachment in create action" do
	    post :create, { :image => { :uploaded_data => fixture_file_upload(SAMPLE_FILES.first, 'image/png', :binary) } }
	    response.status.should eql(200)

	    json_body = JSON.parse(response.body)
	    json_body['filelink'].should =~ /#{File.basename(SAMPLE_FILES.first)}/
	    json_body['filelink'].should =~ /^https:\/\//
	end

	it "should convert base64 to file object and upload an attachment in create_file action" do
		uniquekey = Faker::Number.number(13)
		
		post :create_file, { 
				:dataURI => SAMPLE_DATA_URL, 
				:_uniquekey => uniquekey,
				:format => 'json' 
			}
	    response.status.should eql(200)

	    json_body = JSON.parse(response.body)
	    json_body['filelink'].should =~ /#{"blob" + uniquekey}/
	    json_body['filelink'].should =~ /^https:\/\//
	end
end