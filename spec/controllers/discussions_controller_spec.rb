require 'spec_helper'

describe DiscussionsController do

	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:each) do
		login_admin
	end

	# describe "Displaying recent published and monitored topics" do
	# 	it "should display all published topics" do
	# 		create_dummy_customer
	# 		@user.monitorships.destroy_all
	# 		@forum_category = create_test_category
	# 		@forum = create_test_forum(@forum_category)
	# 		topic1 = create_test_topic(@forum)
	# 		publish_topic(topic1)
	# 		topic2 = create_test_topic(@forum)
	# 		publish_topic(topic2)
	# 		for i in 0..4
	# 			post = create_test_post(topic1)
	# 			publish_post(post) 
	# 		end
	# 		reply_to_topic2 = publish_post(create_test_post(topic2))
	# 		published_topics = @account.topics.as_activities.paginate(:page => params[:page])
	# 		get :index
	# 		response.should render_template("discussions/index")
	# 		fetched_topics_from_controller = controller.instance_variable_get("@topics")
	# 		fetched_topics_from_controller.should =~ published_topics
	# 	end

	# 	it "should display all topics monitored by the user" do
	# 		create_dummy_customer
	# 		@forum_category = create_test_category
	# 		@forum = create_test_forum(@forum_category)
	# 		for i in 0..3
	# 			topic = create_test_topic(@forum)
	# 			publish_topic(topic)
	# 			monitor_topic(topic)
	# 			for i in 0..2
	# 				post = create_test_post(topic)
	# 				publish_post(post)
	# 			end
	# 		end
	# 		my_topics = @user.monitored_topics.as_activities.paginate(:page => params[:page], :per_page => 10)
	# 		get :your_topics
	# 		response.should render_template("discussions/index")
	# 		fetched_topics_from_controller = controller.instance_variable_get("@topics")
	# 		fetched_topics_from_controller.should =~ my_topics
	# 	end
	# end

	describe "Showing all forums under a forum category" do
		it "should display the list of forums under that category on the show page" do
			@forum_category = create_test_category
			for i in 0..4
				@forum = create_test_forum(@forum_category)
			end
			get :show, :id => @forum_category.id
			response.should render_template("discussions/show")
			response.body.should =~ /#{@forum_category.name}/
			category_forums = @forum_category.forums.all(:order => 'position').paginate(:page => controller.params[:page])
      @forum_category.forums.order('position').paginate(:page => controller.params[:page])
      
			fetched_forums_from_controller = controller.instance_variable_get("@forums")
			fetched_forums_from_controller.should =~ category_forums
		end

		it "should redirect to /discussions when the forum_category corresponding to the given id is not found" do
			get :show, :id => 1000
			response.should redirect_to '/discussions'
		end
	end

	describe "Validating and creating a new Forum Category" do
		it "should display the new category form" do
			get :new
			response.should render_template("discussions/new")
		end

		it "should create a new forum category" do
			now = (Time.now.to_f*1000).to_i
			post :create, :forum_category => {:name => "Test category #{now}"}
			@account.forum_categories.find_by_name("Test category #{now}").should be_an_instance_of(ForumCategory)
		end

		it "should not create a new forum category when there is no name" do
			post :create, :forum_category => {}
			response.body.should =~ /Name can&#x27;t be blank/
		end
	end

	describe "Updating a forum category" do
		it "should edit and update a forum category" do
			@forum_category = create_test_category
			now = (Time.now.to_f*1000).to_i
			get :edit, :id => @forum_category.id
			response.body.should =~ /Edit Forum Category/
			put :update, :id => @forum_category.id,
				:forum_category => { :name => "category #{@now}",
															:description => "Testing Category #{@now}"
															}
			@account.forum_categories.find_by_name("category #{@now}").should be_an_instance_of(ForumCategory)
			@account.forum_categories.find_by_description("Testing Category #{@now}").should be_an_instance_of(ForumCategory)
		end
	end

	describe "Listing all the categories present in an account" do
		it "should display all categories" do
			get :categories
			response.should render_template("discussions/categories")
			fetched_categories_from_controller = controller.instance_variable_get("@forum_categories")
			fetched_categories_from_controller.should == @account.forum_categories
		end

		it "should display all categories, underlying forums, my posts, all posts and other views in the sidebar" do
			request.env["HTTP_ACCEPT"] = "application/javascript"
      get :sidebar
			response.should render_template("discussions/shared/_sidebar_categories")
		end
	end

	describe "assigning to main portal after creation" do
		it "should create a record in portal_forum_categories" do
			@forum_category = create_test_category
			result = @account.main_portal.portal_forum_categories.find_by_forum_category_id(@forum_category.id)
			result.should_not be_nil
		end
	end

	describe "assigning to all portals specified" do
		it "should create one record for each specified portal in portal_forum_categories" do

			p1 = create_product({
								:portal_url => "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"
                                })

			p2 = create_product({
                                :portal_url => "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"
                                })
			arr = [p1.portal.id, p2.portal.id]

			post :create, :forum_category => {
												:name => "Test category with portals",
												:portal_ids => arr
											}
											
			category = @account.forum_categories.find_by_name("Test category with portals")
			result = category.portal_forum_categories.map(&:portal_id)
			result.sort.should eql arr.sort
		end
	end
end
