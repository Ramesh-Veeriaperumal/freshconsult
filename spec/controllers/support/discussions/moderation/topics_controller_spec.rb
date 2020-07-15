require 'spec_helper'

describe Support::Discussions::TopicsController do

	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@category = create_test_category
		@forum = create_test_forum(@category)
		@topic = create_test_topic(@forum)
		@user = add_new_user(@account)
		@account.features.spam_dynamo.destroy
	end

	before(:each) do
    @request.env['HTTP_REFERER'] = 'support/discussions'
    log_in(@user)
	end

	after(:all) do
		@category.destroy
	end

	describe "it should create a topic and the details must go to sqs when current user is a customer" do

		before(:each) do
			sqs_config = YAML::load(ERB.new(File.read("#{Rails.root}/config/sqs.yml")).result)
			@moderation_queue = AWS::SQS.new.queues.named(sqs_config["test"]["forums_moderation_queue"])
			SQSPost::SQS_CLIENT = @moderation_queue
			@post_body = Faker::Lorem.paragraph
		end

		it "should create a topic with attachments on post 'create' but the details must go to sqs" do
			topic_title = Faker::Lorem.sentence(1)
			
			post :create,
				:topic =>
						{:title=> topic_title, 
						:body_html=>"<p>#{@post_body}</p>", 
						:forum_id=> @forum.id},
				:post => { :attachments => [{:resource => forum_attachment}]}

			received_message = @moderation_queue.receive_message
			sqs_message = JSON.parse(received_message.body)['sqs_post']

			sqs_message["topic"]["forum_id"].should eql @forum.id
			sqs_message["user"]["id"].should eql @user.id
			sqs_message["account_id"].should eql @account.id
			
			folder_name = sqs_message["attachments"]["folder"]
			s3_bucket_objects = AWS::S3::Bucket.new(S3_CONFIG[:bucket]).objects.with_prefix("spam_attachments")
			sqs_message["attachments"]["file_names"].each do |file_name|
				s3_bucket_objects.map(&:key).include?("#{folder_name}/#{file_name}").should eql true
			end

			response.should redirect_to '/support/discussions'

			# moderation_queue.delete
			@moderation_queue.batch_delete(received_message)
			begin
				s3_bucket_objects.delete_all
			rescue Exception => e
				p "*******Exception********"
				p e
			end
		end

		it "should not create a topic on post 'create' when post is invalid and the details must not go to sqs" do
			post :create,
				:topic =>
						{
						:body_html=>"", 
						:forum_id=> @forum.id},
				:post => { :attachments => [{:resource => forum_attachment}]}

			@moderation_queue.receive_message.should be nil
			
			response.should render_template 'support/discussions/topics/new'
		end

	end

end