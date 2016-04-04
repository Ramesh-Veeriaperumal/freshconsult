require 'spec_helper'

describe Discussions::MergeTopicController do

	setup :activate_authlogic
	self.use_transactional_fixtures = false
	
	before(:all) do
		@user = add_test_agent(@account)
		@user1 = add_new_user(@account)
		@user2 = add_new_user(@account)
		@category = create_test_category
		@forum = create_test_forum(@category)
		@source1 = create_test_topic(@forum)
		@source2 = create_test_topic(@forum)
		@target = create_test_topic(@forum)
		Resque.inline = true
	end

	before(:each) do
		@request.host = @account.full_domain
		log_in(@user)
	end

	after(:all) do
		Resque.inline = false
	end

	describe 'merge all source topics' do
		
		before(:all) do
			@note = Faker::Lorem.paragraph
			monitor_topic(@source1, @user1)
			monitor_topic(@source2, @user2)
			vote_topic(@source1, @user1)
			vote_topic(@source2, @user2)
			@post_count = Post.all.count
			@vote_count = Vote.all.count
			@monitorship_count = Monitorship.all.count
			@activity_count = Helpdesk::Activity.all.count
		end

		before(:each) do
			post :confirm, {:source_note => @note, 
											:source_topics => [@source1.id,@source2.id], 
											:target_topic_id => @target.id,
											:redirect_back => false}
		end

		it 'should lock all source topics' do
			@source1.reload
			@source2.reload
			
			@source1.locked.should be true
			@source2.locked.should be true
		end

		it 'should set target id in all source topics' do
			@source1.reload
			@source2.reload
			@target.reload
			
			@source1.merged_topic_id.should be_eql @target.id
			@source2.merged_topic_id.should be_eql @target.id
			
			@target.merged_topic_id?.should_not be true
		end

		it 'should not lock the target topic' do
			@target.locked.should_not be true
		end

		it 'should add a reply to all source topics if source note is not blank' do
			@source1.posts.last.body.should eql @note
			@source2.posts.last.body.should eql @note
		end

		it 'should add a merge activity for each source topic' do
			merge_activity1 = @source1.activities.last
			merge_activity2 = @source2.activities.last

			merge_activity1.notable_id.should eql @source1.id
			merge_activity1.notable_type.should eql 'Topic'
			merge_activity1.description.should eql 'activities.forums.topic_merge.long'

			merge_activity2.notable_id.should eql @source2.id
			merge_activity2.notable_type.should eql 'Topic'
			merge_activity2.description.should eql 'activities.forums.topic_merge.long'
		end

		it 'should copy monitorships from source to target topic' do			
			monitorship = @user1.monitorships.last
			monitorship.monitorable_id.should eql @target.id
			monitorship.monitorable_type.should eql 'Topic'
			monitorship.active.should be true

			monitorship = @user2.monitorships.last
			monitorship.monitorable_id.should eql @target.id
			monitorship.monitorable_type.should eql 'Topic'
			monitorship.active.should be true
		end

		it 'should copy votes from source to target topic' do
			vote = @user1.votes.last
			vote.voteable_id.should eql @target.id
			vote.voteable_type.should eql 'Topic'
			vote.vote?.should be true

			vote = @user2.votes.last
			vote.voteable_id.should eql @target.id
			vote.voteable_type.should eql 'Topic'
			vote.vote?.should be true
		end

		it 'should send merge email notification to target topic followers' do
		end

		it 'should add a new post activity for all source topics if source is not blank' do
			@source1.posts.last.activities.first.present?.should be true
			@source2.posts.last.activities.first.present?.should be true
		end

	end

	describe 'merge all source topics with duplicate monitorships, votes and no merge note' do
		
		before(:all) do
			@note = '<p></p>'
			@source = create_test_topic(@forum)
			monitor_topic(@source, @user1)
			monitor_topic(@target, @user1)
			vote_topic(@source, @user1)
			vote_topic(@target, @user1)
			@post_count = Post.all.count
			@vote_count = Vote.all.count
			@monitorship_count = Monitorship.all.count
			@activity_count = Helpdesk::Activity.all.count
		end

		before(:each) do
			post :confirm,{:source_note => @note, 
										 :source_topics => [@source1.id,@source2.id], 
										 :target_topic_id => @target.id,
										 :redirect_back => false }
		end

		it 'should not duplicate monitorships while copying existing monitorships from source to target topic' do			
			Monitorship.all.count.should eql @monitorship_count
		end

		it 'should not duplicate votes while copying existing votes from source to target topic' do
			Vote.all.count.should eql @vote_count
		end

		it 'should not add a reply to all source topics if merge note is blank' do
			Post.all.count.should eql @post_count
		end

		it 'should not add a new post activity for all source topics if source is blank' do
			@source.posts.last.activities.first.present?.should_not be true
		end

	end

end