require 'spec_helper'

describe Discussions::ForumsController do

	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@user = add_test_agent(@account)
	end

	before(:each) do
		@request.host = @account.full_domain
		log_in(@user)
	end

	describe "Validating and creating a new Forum" do
		it "should display the new forum form" do
			get :new
			response.should render_template("discussions/forums/new")
		end

		it "should create a new forum" do
			now = (Time.now.to_f*1000).to_i
			@forum_category = create_test_category
			post :create, :forum => { :name => "Test forum #{now}", 
																:forum_category_id => @forum_category.id, 
																:forum_type => 1,
																:forum_visibility => 1
															}
			@account.forums.find_by_name("Test forum #{now}").should be_an_instance_of(Forum)
		end

		it "should not create a new forum without a name" do 
			now = (Time.now.to_f*1000).to_i
			@forum_category = create_test_category
			post :create, :forum => { 
																:forum_category_id => @forum_category.id, 
																:forum_type => 1,
																:forum_visibility => 1
															}
			response.body.should =~ /Name can&#x27;t be blank/
		end

		it "should not create a new forum without a forum category" do 
			now = (Time.now.to_f*1000).to_i
			post :create, :forum => { 
																:name => "Test forum #{now}", 
																:forum_type => 1,
																:forum_visibility => 1
															}
			response.should redirect_to '/discussions'
		end

		it "should not create a new forum without a forum type" do 
			now = (Time.now.to_f*1000).to_i    
			@forum_category = create_test_category
			post :create, :forum => { 
																:name => "Test forum #{now}", 
																:forum_category_id => @forum_category.id, 
																:forum_visibility => 1
															}
			response.body.should =~ /Forum type can&#x27;t be blank/
		end

		it "should not create a new forum without forum visibility" do 
			now = (Time.now.to_f*1000).to_i    
			@forum_category = create_test_category
			post :create, :forum => { 
																:name => "Test forum #{now}", 
																:forum_category_id => @forum_category.id, 
																:forum_type => 1
															}
			response.body.should =~ /Forum visibility is not included in the list/
		end
	end

	describe "Updating a Forum" do
		it "should edit and update a forum" do
			@forum_category = create_test_category
			@forum = create_test_forum(@forum_category)
			now = (Time.now.to_f*1000).to_i
			get :edit, :id => @forum.id
			response.body.should =~ /Edit Forum/
			put :update, :id => @forum.id, 
				:forum => { :name => "Forum #{@now}",
										:description => "Testing Forum #{@now}"
									}
			@account.forums.find_by_name("Forum #{@now}").should be_an_instance_of(Forum)
		end

		it "should not update a forum if validation fails" do
			@forum_category = create_test_category
			forum = create_test_forum(@forum_category)
			another_forum = create_test_forum(@forum_category)
			put :update, :id => another_forum.id, 
				:forum => { :name => forum.name }
			response.body.should =~ /Name already exists in the selected category/
			response.should render_template 'discussions/forums/edit'
		end
	end

	describe "Showing topics under a forum according to the filters specified" do
		it "should list all published topics under a forum" do
			@forum_category = create_test_category
			@forum = create_test_forum(@forum_category)
			for i in 0..3
				topic = create_test_topic(@forum)
				publish_topic(topic)
				monitor_topic(topic)
				for i in 0..2
					post = create_test_post(topic)
					publish_post(post)
				end
			end
			get :show, :id => @forum.id
			response.should render_template 'discussions/forums/show'
			fetched_topics_from_controller = controller.instance_variable_get("@topics")
			topics = @forum.topics.newest
			topics = topics.published.find(:all, :include => :votes).sort_by { |u| 
																	[-u.sticky,-u.votes.size] }.paginate(:page => controller.params[:page],:per_page => 10)
			fetched_topics_from_controller.should =~ topics
		end

		it "should list all popular published topics under a forum" do
			@forum_category = create_test_category
			@forum = create_test_forum(@forum_category)
			for i in 0..3
				topic = create_test_topic(@forum)
				publish_topic(topic)
				monitor_topic(topic)
				for i in 0..2
					post = create_test_post(topic)
					publish_post(post)
				end
			end
			get :show, :id => @forum.id, :order => 'popular'
			response.should render_template 'discussions/forums/show'
			fetched_topics_from_controller = controller.instance_variable_get("@topics")
			topics = @forum.topics.popular(3.months.ago)
			topics = topics.published.find(:all, :include => :votes).sort_by { |u| 
																	[-u.sticky,-u.votes.size] }.paginate(:page => controller.params[:page],:per_page => 10)
			fetched_topics_from_controller.should =~ topics
		end

		it "should list all published topics under a forum with the given stamps" do
			@forum_category = create_test_category
			@forum = create_test_forum(@forum_category)
			for i in 0..3
				topic = create_test_topic(@forum)
				publish_topic(topic)
				monitor_topic(topic)
				for i in 0..2
					post = create_test_post(topic)
					publish_post(post)
				end
			end
			forum_type_symbol = Forum::TYPE_KEYS_BY_TOKEN[Forum::TYPE_SYMBOL_BY_KEY[@forum.forum_type]]
			stamp_types = Topic::ALL_TOKENS_FOR_FILTER[forum_type_symbol].keys.sample(2)
			get :show, :id => @forum.id, :filter => stamp_types.join(",")
			response.should render_template 'discussions/forums/show'
			fetched_topics_from_controller = controller.instance_variable_get("@topics")
			topics = @forum.topics.newest
			topics = topics.published.find(:all,:conditions => ["stamp_type IN (?)", stamp_types]).paginate(
																																	:page => controller.params[:page],:per_page => 10)
			fetched_topics_from_controller.should =~ topics
		end
	end

	describe "Reordering forums" do
		it "should reorder forums under a category" do
			@forum_category = create_test_category
			position_arr = (1..4).to_a.shuffle
			reorder_hash = {}
			for i in 0..3
				forum = create_test_forum(@forum_category)
				reorder_hash[forum.id] = position_arr[i] 
			end
			put :reorder, :format => "js", "reorderlist" => reorder_hash.to_json, :category_id => @forum_category.id
			@forum_category.forums.each do |f|
				f.position.should be_eql(reorder_hash[f.id])
			end
			response.code.should be_eql("200")
			put :reorder, "reorderlist" => reorder_hash.to_json
			response.should redirect_to('/discussions')	
		end
	end

	describe "Destroying a forum" do
		it "should delete a forum" do
			@forum_category = create_test_category
			@forum = create_test_forum(@forum_category)
			for i in 0..3
				topic = create_test_topic(@forum)
				publish_topic(topic)
			end
			delete :destroy, :id => @forum.id
			@account.forums.find_by_id(@forum.id).should be_nil
		end
	end

	describe "Checking if the user can view the forums" do
		it "should redirect to support_discussions_path when user is not logged in" do
			@forum_category = create_test_category
			@forum = create_test_forum(@forum_category)
			destroy_session
			get :show, :id => @forum.id
			response.should redirect_to(support_discussions_forum_path(@forum))
		end
	end	

	it "should render followers list" do 
		forum_category = create_test_category
		forum = create_test_forum(forum_category)
		get :followers, :id => forum.id
		response.should render_template('discussions/forums/followers')
	end

end