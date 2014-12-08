require 'spec_helper'

describe Monitorship do

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
end