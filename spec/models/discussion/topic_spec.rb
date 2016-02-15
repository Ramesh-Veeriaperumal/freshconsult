require 'spec_helper'

describe Topic do 

	describe "Activities for Topics: " do

		before(:all) do
			@category = create_test_category
			@forum = create_test_forum(@category)
		end

		before(:each) do
			@topic = create_test_topic(@forum)
		end

		it "should create activity when topic is created" do
			@topic.activities.last.description.should eql 'activities.forums.new_topic.long'
			@topic.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create activity when topic is destroyed" do
			@topic.destroy
			@topic.activities.last.description.should eql 'activities.forums.delete_topic.long'
			@topic.activities.last.updated_at.to_date.should eql Time.now.to_date
		end

		it "should create an activity with correct agent" do
			@agent.make_current
			@topic.destroy
			@topic.activities.last.user_id.should eql @agent.id
		end

		it "should create activity of Topic notable type" do
			@topic.destroy
			@topic.activities.last.notable_type.should eql 'Topic'
		end

		it "should create activity with the correct path in activity data" do
			@topic.destroy
			@topic.activities.last.activity_data[:path].should eql Rails.application.routes.url_helpers.discussions_topic_path(@topic.id)
		end
		
		it "should create activity with the correct title in activity data" do
			@topic.destroy
			@topic.activities.last.activity_data[:title].should eql @topic.title.to_s
		end

		it "should create activity with the correct description" do
			@topic.activities.last.description.should eql 'activities.forums.new_topic.long'
			@topic.destroy
			@topic.activities.last.description.should eql 'activities.forums.delete_topic.long'
		end

		it "should create activity with the correct short description" do
			@topic.activities.last.short_descr.should eql 'activities.forums.new_topic.short'
			@topic.destroy
			@topic.activities.last.short_descr.should eql 'activities.forums.delete_topic.short'
		end

		it "should create only one activity for each action(create/delete)" do
			@topic.activities.size.should eql 1
			@topic.destroy
			@topic.activities.size.should eql 2
		end


		describe 'Topic stamp types :'do

			before(:all) do
				@category = create_test_category
			end

			describe 'Problem forum topic:' do

				before(:each) do
					@forum_problem = create_test_forum(@category, Forum::TYPE_KEYS_BY_TOKEN[:problem])
					@topic = create_test_topic(@forum_problem)
				end

				it "should create activity when problem topic is marked solved" do
					@topic.activities.size.should eql 1
					@topic.toggle_solved_stamp
					@topic.activities.size.should eql 2
					@topic.activities.last.description.should eql 'activities.forums.topic_stamp_8.long'
					@topic.activities.last.updated_at.to_date.should eql Time.now.to_date
				end

				it "should create activity when problem topic is marked unsolved" do
					@topic.activities.size.should eql 1
					@topic.toggle_solved_stamp #Solve topic
					@topic.toggle_solved_stamp #Unsolve topic
					@topic.activities.size.should eql 3
					@topic.activities.last.description.should eql 'activities.forums.topic_stamp_9.long'
					@topic.activities.last.updated_at.to_date.should eql Time.now.to_date
				end

			end

			describe 'Feature requests topic:' do

				before(:each) do
					@forum_problem = create_test_forum(@category, Forum::TYPE_KEYS_BY_TOKEN[:ideas])
					@topic = create_test_topic(@forum_problem)
				end

				it "should create activity when idea topic is marked planned" do
					@topic.stamp_type =  Topic::IDEAS_STAMPS_BY_TOKEN[:planned]
					@topic.save
					@topic.activities.size.should eql 2
					@topic.activities.last.description.should eql 'activities.forums.topic_stamp_1.long'
					@topic.activities.last.updated_at.to_date.should eql Time.now.to_date
				end

				it "should create activity when idea topic is marked inprogress" do
					@topic.stamp_type = Topic::IDEAS_STAMPS_BY_TOKEN[:planned]
					@topic.save
					@topic.stamp_type = Topic::IDEAS_STAMPS_BY_TOKEN[:inprogress]
					@topic.save
					@topic.activities.size.should eql 3
					@topic.activities.last.description.should eql 'activities.forums.topic_stamp_4.long'
					@topic.activities.last.updated_at.to_date.should eql Time.now.to_date
				end

				it "should create activity when idea topic is marked deferred" do
					@topic.stamp_type = Topic::IDEAS_STAMPS_BY_TOKEN[:deferred]
					@topic.save
					@topic.activities.size.should eql 2
					@topic.activities.last.description.should eql 'activities.forums.topic_stamp_5.long'
					@topic.activities.last.updated_at.to_date.should eql Time.now.to_date
				end

				it "should create activity when idea topic is marked implemented" do
					@topic.stamp_type = Topic::IDEAS_STAMPS_BY_TOKEN[:implemented]
					@topic.save
					@topic.activities.size.should eql 2
					@topic.activities.last.description.should eql 'activities.forums.topic_stamp_2.long'
					@topic.activities.last.updated_at.to_date.should eql Time.now.to_date
				end

				it "should create activity when idea topic is marked nottaken" do
					@topic.stamp_type = Topic::IDEAS_STAMPS_BY_TOKEN[:nottaken]
					@topic.save
					@topic.activities.size.should eql 2
					@topic.activities.last.description.should eql 'activities.forums.topic_stamp_3.long'
					@topic.activities.last.updated_at.to_date.should eql Time.now.to_date
				end

			end


			describe 'Question forum topic:' do

				before(:each) do
					@forum_problem = create_test_forum(@category, Forum::TYPE_KEYS_BY_TOKEN[:howto])
					@topic = create_test_topic(@forum_problem)
					@post = create_test_post(@topic)
				end

				it "should create activity when question topic is marked answered" do
					@post.toggle_answer
					@topic.activities.size.should eql 2
					@topic.activities.last.description.should eql 'activities.forums.topic_stamp_6.long'
					@topic.activities.last.updated_at.to_date.should eql Time.now.to_date
				end

				it "should create activity when question topic is marked unanswered" do
					@post.toggle_answer
					@post.toggle_answer
					@topic.activities.size.should eql 3
					@topic.activities.last.description.should eql 'activities.forums.topic_stamp_7.long'
					@topic.activities.last.updated_at.to_date.should eql Time.now.to_date
				end
			end

		end
	end

	describe "Topic to Ticket: " do

		before(:all) do
			@category = create_test_category
			@forum_with_convert_to_ticket = create_test_forum(@category, 1, nil, 1)
			@forum_without_convert_to_ticket = create_test_forum(@category, 1, nil, 0)
		end

		it "should create ticket for a topic, if 'convert_to_ticket' is set for the forum" do
			@topic = create_test_topic(@forum_with_convert_to_ticket)
			@topic.ticket_topic.should_not eql nil
		end

		it "should NOT create ticket for a topic, if 'convert_to_ticket' is NOT set for the forum" do
			@topic = create_test_topic(@forum_without_convert_to_ticket)
			@topic.ticket_topic.should eql nil
		end

		it "should create ticket with attachment if the topic has an attachment, if 'convert_to_ticket' is set for the forum" do
			@topic = create_test_topic_with_attachments(@forum_with_convert_to_ticket)
			@topic.ticket.attachments.should_not eql []
		end

		it "should create ticket with cloud file attachment if the topic has an attachment, if 'convert_to_ticket' is set for the forum" do
			@topic = create_test_topic_with_cloud_files(@forum_with_convert_to_ticket)
			@topic.ticket.cloud_files.should_not eql []
		end

		it "Should create a ticket with fields populated from the topic, if 'convert_to_ticket' is set for the forum" do
			@topic = create_test_topic(@forum_with_convert_to_ticket)
			@topic.ticket.subject.should eql @topic.title
        	@topic.ticket.description.should eql @topic.posts.first.body
    		@topic.ticket.requester.should eql @topic.user
    		@topic.ticket.source.should eql Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:forum]
		end

		it "Should NOT create a ticket if the user is an agent and if 'convert_to_ticket' is set for the forum" do
			@agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
			@agent.make_current
			@topic = create_test_topic(@forum_with_convert_to_ticket, @agent)
			@topic.ticket_topic.should eql nil
		end
	end
end
