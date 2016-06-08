require 'spec_helper'

describe Monitorship do

	self.use_transactional_fixtures = false
	
	before(:all) do
		@admin = get_admin
		@product = create_product({:email => "test_product@localhost.freshpo.com",:portal_name=> "New test_product portal", 
			                            :portal_url => "test.product.com"})
		topic = create_test_topic(Forum.last,@admin)
		publish_topic(topic)
		post = create_test_post(topic,@admin)
		publish_post(post)
		@user = add_new_user(@admin.account)
		@user.make_current
		monitor_topic(topic, @admin, Portal.first)
		post = create_test_post(topic, @admin)
		publish_post(post)
		@monitorship = Monitorship.last
 	end

 	it "should assign the default sender and host when the portal is nil" do
 		@monitorship.update_attributes(:portal_id => nil)
 		mail_options = @monitorship.sender_and_host
 		mail_options.first.should == @monitorship.account.default_friendly_email
 		mail_options.last.should == @monitorship.account.host
 	end

 	it "should assign the right sender and host when the portal is set" do
 		portal = @product.portal
 		@monitorship.update_attributes(:portal_id => portal.id)
 		mail_options = @monitorship.sender_and_host
 		mail_options.first.should == portal.friendly_email
 		mail_options.last.should == portal.host
 	end

 	it "should assign the default sender and host when the portal_id is that of a non-existent portal" do
 		random_portal_id = Portal.last.id + Time.now.utc.to_i
 		@monitorship.update_attributes(:portal_id => random_portal_id)
 		mail_options = @monitorship.reload.sender_and_host
 		mail_options.first.should == @monitorship.account.default_friendly_email
 		mail_options.last.should == @monitorship.account.host
 	end

 	describe "Topic Merge" do
 		before(:each) do
 			@admin.make_current
 			@forum_category = create_test_category
 			@forum = create_test_forum(@forum_category)
 			@topic1 = create_test_topic(@forum)
 			@topic2 = create_test_topic(@forum)
 			@users = []
 			4.times do 
 			  @users <<  add_test_agent(@account) 
 			end
 		end

 		it "should not send notification mail for topic merge" do 
 			monitor_topic(@topic1, @users[0])
 			monitor_topic(@topic1, @users[1])
 			monitor_topic(@topic2, @users[2])
 			monitor_topic(@topic2, @users[3])
 			Delayed::Job.delete_all
 			@topic2.update_attributes(:locked => 1, :merged_topic_id => @topic1.id)
 			@topic2.merge_followers(@topic1)
 			Delayed::Job.count.should == 0
 		end
 	end
end