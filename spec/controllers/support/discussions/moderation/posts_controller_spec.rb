require 'spec_helper'

describe Support::Discussions::PostsController do
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


	describe "it should create a post in sqs when spam_dynamo feature is enabled" do

		before(:all) do
			@account.features.spam_dynamo.create
		end

		before(:each) do
			sqs_config = YAML::load(ERB.new(File.read("#{Rails.root}/config/sqs.yml")).result)
			@moderation_queue = AWS::SQS.new.queues.named(sqs_config["test"]["forums_moderation_queue"])
			SQSPost::SQS_CLIENT = @moderation_queue
			@sample_topic = publish_topic(create_test_topic(@forum))
		end

		it "should create a post with attachments on post 'create' but the details must go to sqs if spam_dynamo feature is enabled" do
			post_body = Faker::Lorem.paragraph
		
			post :create,
				:topic_id => @sample_topic.id,
				:post => { :body_html =>"<p>#{post_body}</p>",
					:attachments => [{:resource => forum_attachment }]}

			received_message = @moderation_queue.receive_message
			sqs_message = JSON.parse(received_message.body)['sqs_post']

			sqs_message["topic"]["id"].should eql @sample_topic.id
			sqs_message["user"]["id"].should eql @user.id
			sqs_message["account_id"].should eql @account.id
			
			folder_name = sqs_message["attachments"]["folder"]
			s3_bucket_objects = AWS::S3::Bucket.new(S3_CONFIG[:bucket]).objects.with_prefix("spam_attachments")
			sqs_message["attachments"]["file_names"].each do |file_name|
				s3_bucket_objects.map(&:key).include?("#{folder_name}/#{file_name}").should eql true
			end

			response.should redirect_to "/support/discussions/topics/#{@sample_topic.id}?page=1"

			# moderation_queue.delete
			@moderation_queue.batch_delete(received_message)
			begin
				s3_bucket_objects.delete_all
			rescue Exception => e
				p "*******Exception********"
				p e
			end
		end

		it "should not create a post in sqs on post 'create' when the post is invalid" do
			
			post :create, 
						:post => {
								:body_html =>""
								},
						:topic_id => @sample_topic.id

			@moderation_queue.receive_message.should be nil

			response.should redirect_to "/support/discussions/topics/#{@sample_topic.id}?page=1"
		end

		after(:all) do
			@account.features.spam_dynamo.destroy
		end
	end

end
