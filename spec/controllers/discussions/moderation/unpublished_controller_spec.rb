require 'spec_helper'

describe Discussions::UnpublishedController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		$dynamo = Aws::DynamoDB::Client.new
		Dynamo::CLIENT = $dynamo
		@category = create_test_category
		@forum = create_test_forum(@category)
		@topic = create_test_topic(@forum)
	end

	before(:each) do
    @request.env['HTTP_REFERER'] = '/categories'
	  login_admin
	end

	after(:each) do
		delete_dynamo_posts("ForumSpam")
	  delete_dynamo_posts("ForumUnpublished")
	end

	after(:all) do
		@account.reload
		@category.destroy
	end

	it "should go to the index page" do
		(1..3).each do
			create_dynamo_topic("ForumSpam", @forum)
		end

    get 'index'

    response.should render_template "discussions/unpublished/index"
	end

	it "should publish a topic on 'approve'" do
		unpublished_topic = create_dynamo_topic("ForumSpam", @forum)

		Resque.inline = true

		put :approve, :id => unpublished_topic, 
									:scope => "ForumSpam", 
									:timestamp => unpublished_topic.timestamp

		Resque.inline = false

		new_topic = @account.topics.find_by_title(unpublished_topic.title)
		new_topic.should_not be_nil
		new_topic.posts.first.body_html.should eql unpublished_topic.body_html
		new_topic.forum_id.should eql unpublished_topic.forum_id
		new_topic.account_id.should eql unpublished_topic.account_id
		new_topic.user_id.should eql @customer.id
		ForumSpam.find_post(unpublished_topic.timestamp).should be_nil
	end

	it "should publish a post on 'approve'" do
		unpublished_post = create_dynamo_post("ForumSpam", @topic)

		Resque.inline = true

		put :approve, :id => unpublished_post,
									:scope => "ForumSpam", 
									:timestamp => unpublished_post.timestamp

		Resque.inline = false

		new_post = @account.posts.find_by_body_html(unpublished_post.body_html)
		new_post.should_not be_nil
		new_post.account_id.should eql unpublished_post.account_id
		new_post.user_id.should eql @customer.id
		new_post.topic_id.should eql @topic.id
		ForumSpam.find_post(unpublished_post.timestamp).should be_nil
	end

	it "should publish a post on 'approve' and create attachments accordingly" do
		unpublished_topic = create_dynamo_topic("ForumSpam", @forum, {:attachment => true})
		S3_CONFIG = YAML::load(ERB.new(File.read("#{Rails.root}/config/s3.yml")).result)["test"].symbolize_keys

		Resque.inline = true

		put :approve, :id => unpublished_topic, 
									:scope => "ForumSpam", 
									:timestamp => unpublished_topic.timestamp

		Resque.inline = false

		new_topic = @account.topics.find_by_title(unpublished_topic.title)
		original_post = new_topic.posts.first
		new_topic.should_not be_nil
		new_topic.posts.first.body_html.should eql unpublished_topic.body_html
		new_topic.forum_id.should eql unpublished_topic.forum_id
		new_topic.account_id.should eql unpublished_topic.account_id
		new_topic.user_id.should eql @customer.id
		original_post.attachments.each_with_index do |attachment, i|
			file_name = unpublished_topic.attachments["file_names"][i].split('/').last.split('?').first.split('_')[1..-1].join.gsub("%20"," ")
			attachment.content_file_name.should eql file_name
		end
		ForumSpam.find_post(unpublished_topic.timestamp).should be_nil
	end

	it "delete all published, spam, approval posts of a given user on 'ban'" do
		user = add_new_user(@account)
		unpublished_topic = create_dynamo_topic("ForumUnpublished", @forum, user_timestamp_params(user))
		unpublished_topic.should_not be_nil
		unpublished_post = create_dynamo_post("ForumUnpublished", @topic, user_timestamp_params(user))
		unpublished_post.should_not be_nil
		published_topic = create_test_topic(@forum, user)
		published_post = create_test_post(@topic, user)

		Resque.inline = true

		put :ban, :id => unpublished_topic, 
							:scope => "ForumUnpublished", 
							:timestamp => unpublished_topic.timestamp

		Resque.inline = false

		ForumUnpublished.find_post(unpublished_topic.timestamp).should be_nil
		ForumUnpublished.find_post(unpublished_post.timestamp).should be_nil
		@account.topics.find_by_id(published_topic.id).should be_nil
		@account.topics.find_by_id(published_post.id).should be_nil
	end

	it "empty all spam of a given account on 'empty_folder'" do
		(1..3).each do
			create_dynamo_topic("ForumSpam", @forum)
		end

		(1..3).each do
			create_dynamo_post("ForumSpam", @topic)
		end
		ForumSpam.query(:account_id => @account.id).records.should_not eql []

		Resque.inline = true

		delete :empty_folder

		Resque.inline = false

		ForumSpam.query(:account_id => @account.id).records.should eql []
	end

	it "empty all spam of a given topic on 'empty_topic_spam'" do
		(1..5).each do
			create_dynamo_post("ForumSpam", @topic)
		end
		ForumSpam.topic_spam(@topic.id).records.should_not eql []

		Resque.inline = true

		delete :empty_topic_spam, :id => @topic.id

		Resque.inline = false

		ForumSpam.topic_spam(@topic.id).records.should eql []
	end

	it "should create a spam dynamo post when 'put 'mark_as_spam''" do
		published_topic = publish_topic(create_test_topic(@forum))
		post = published_topic.posts.first

		Resque.inline = true

		put :mark_as_spam, :id => post.id

		Resque.inline = false

		dynamo_post = ForumSpam.find_post(post.created_at.to_f)
		dynamo_post.should_not be_nil
		dynamo_post.title.should eql published_topic.title
		dynamo_post.forum_id.should eql published_topic.forum_id
		@account.topics.find_by_id(published_topic.id).should be_nil
	end

	it "should create a spam dynamo post and backup attachments when a post with attachments is marked as spam" do
		published_topic = publish_topic(create_test_topic_with_attachments(@forum))
		original_post = published_topic.posts.first

		Resque.inline = true

		put :mark_as_spam, :id => original_post.id

		Resque.inline = false

		dynamo_post = ForumSpam.find_post(original_post.created_at.to_f)
		dynamo_post.should_not be_nil
		dynamo_post.title.should eql published_topic.title
		dynamo_post.forum_id.should eql published_topic.forum_id
		@account.topics.find_by_id(published_topic.id).should be_nil
		original_post.attachments.each_with_index do |attachment, i|
			folder_name = dynamo_post.attachments["folder"]
			file_name = dynamo_post.attachments["file_names"][i].split('/').last.split('?').first.split('_')[1..-1].join.gsub("%20"," ")
			attachment.content_file_name.should eql file_name
			s3_bucket_objects = AwsWrapper::S3.find_with_prefix(S3_CONFIG[:bucket], "spam_attachments")
			s3_bucket_objects.map(&:key).include?("#{folder_name}/#{dynamo_post.attachments["file_names"][i]}").should eql true
		end
	end

	it "should delete the dynamo post on 'delete_unpublished'" do
		unpublished_topic = create_dynamo_topic("ForumSpam", @forum)

		delete :delete_unpublished, :id => unpublished_topic, 
																:timestamp => unpublished_topic.timestamp, 
																:scope => "ForumSpam",
																:topic_id => unpublished_topic.topic_id

		ForumSpam.find_post(unpublished_topic.timestamp).should be_nil
	end


	it "should mark as spam multiple posts when 'put 'spam_multiple''" do
		published_topics = []
		(1..3).each do
			published_topics << publish_topic(create_test_topic(@forum))
			sleep 2
		end

		Resque.inline = true

		put :spam_multiple, :ids => published_topics.map(&:id)

		Resque.inline = false

		published_topics.each do |topic|
			@account.topics.find_by_id(topic.id).should be_nil
			dynamo_post = ForumSpam.find_post(topic.created_at.to_f)
			dynamo_post.should_not be_nil
			dynamo_post.title.should eql topic.title
			dynamo_post.forum_id.should eql topic.forum_id
		end
	end

	it "should render topic_spam_posts" do
		published_topic = publish_topic(create_test_topic(@forum))
		approval_posts = []
		(1..3).each do
			approval_posts << create_dynamo_post("ForumUnpublished", published_topic).attributes
			sleep 1
		end

		get :topic_spam_posts, :id => published_topic.id, :filter => 'unpublished'

		posts_from_controller = controller.instance_variable_get("@spam_posts").records.map(&:attributes)
		posts_from_controller.should =~ approval_posts
		response.should render_template "discussions/unpublished/topic_spam_posts"
	end

	it "should render more for pagination" do
		create_dynamo_topic("ForumSpam", @forum, {:timestamp => (Time.now - 1.day).utc.to_f})

		last_2_days_posts = []
		for i in [2,3] do
			last_2_days_posts << create_dynamo_topic("ForumSpam", @forum, {:timestamp => (Time.now - i.day).utc.to_f}).attributes
		end

		get :more, :filter => 'spam', :next => (Time.now - 2.day).utc.to_f

		posts_from_controller = controller.instance_variable_get("@spam_posts").records.map(&:attributes)
		posts_from_controller.should =~ last_2_days_posts
	end

end