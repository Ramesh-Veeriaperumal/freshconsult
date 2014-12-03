require 'spec_helper'

# describe Social::FacebookSubscriptionController do
#   #Delete these examples and add some real ones
#   before(:all) do
#     @account = create_test_account
#     Social::FacebookPage.any_instance.stubs(:after_commit_on_create => true)
#     Social::FacebookPage.any_instance.stubs(:after_commit_on_update => true)
#     FBClient.any_instance.stubs(:subscribe_for_page).returns(true)
#     # Facebook::Fql::Posts.any_instance.stubs(:fetch).returns({})
#     fb_page = FactoryGirl.build(:facebook_pages)
#     fb_page.account_id = @account.id
#     fb_page.save(validate: false)
#   end

#   after(:all) do
#     FBClient.any_instance.stubs(:subscribe_for_page).returns(true)
#     # Facebook::Fql::Posts.any_instance.stubs(:fetch).returns({})
#     Social::FacebookPage.destroy_all
#   end

#   after(:each) do
#     Helpdesk::Ticket.destroy_all
#   end

#   describe "Get request from facebook" do
#     it "get request without params should not authorize facebook" do
#       @request.host = "foo2.freshpo.com"
#       get 'subscription'
#       response.body.should eql "Failed to authorize facebook challenge request"
#     end

#     it "get request to subscribe and return the challenge to validate the url " do
#       @request.host = "foo2.freshpo.com"
#       get 'subscription', {"hub.mode" => "subscribe","hub.verify_token" => "tokenforfreshdesk", "hub.challenge" => "12345"}
#       response.body.should eql "12345"
#     end
#   end

#   describe "Post request from facebook" do
#     it "should process the request" do
#       @request.host = "foo2.freshpo.com"
#       @request.env["HTTP_ACCEPT"] = "application/json"
#       @request.env["RAW_POST_DATA"]  = { "token" => 0 }.to_json
#       post 'subscription'
#       response.body.should eql "Thanks for the update"
#     end
#     it "should call the method atleast once" do
#       @request.host = "foo2.freshpo.com"
#       @request.env["HTTP_ACCEPT"] = "application/json"
#       @request.env["RAW_POST_DATA"]  = { "token" => 0 }.to_json
#       Social::FacebookSubscriptionController.expects(:process_facebook_request).at_least_once.returns({})
#       post 'subscription'
#       response.body.should eql "Thanks for the update"
#     end

#     context "should create a ticket from a facebook" do
#       it "post (add_post)" do
#         @request.host = "foo2.freshpo.com"
#         @request.env["HTTP_ACCEPT"] = "application/json"
#         @request.env["RAW_POST_DATA"]  = {"object"=>"page", "entry"=>[{"id"=>"532218423476440", "time"=>1368771694, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"post", "verb"=>"add", "post_id"=>574929992538616}}]}]}.to_json
#         Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns({"privacy"=>{"value"=>""}, "to"=>{"data"=>[{"name"=>"Causeeeeeeeadded", "category"=>"Cause", "id"=>"532218423476440"}]}, "from"=>{"name"=>"Richardo Paul", "id"=>"100005815842768"}, "updated_time"=>"2013-05-17T06:24:25+0000", "message"=>"this is really awesome place to start", "comments"=>{"paging"=>{"cursors"=>{"before"=>"MQ==", "after"=>"MQ=="}}, "data"=>[{"can_remove"=>true, "from"=>{"name"=>"Richardo Paul", "id"=>"100005815842768"}, "message"=>"hahaha", "user_likes"=>false, "like_count"=>0, "created_time"=>"2013-05-17T06:22:48+0000", "id"=>"574929992538616_6910298"}]}, "created_time"=>"2013-05-17T06:21:34+0000", "id"=>"532218423476440_574929992538616", "type"=>"status", "actions"=>[{"link"=>"http://www.facebook.com/532218423476440/posts/574929992538616", "name"=>"Comment"}, {"link"=>"http://www.facebook.com/532218423476440/posts/574929992538616", "name"=>"Like"}]})
#         post 'subscription'
#         Helpdesk::Ticket.all.size.should eql 1
#         response.body.should eql "Thanks for the update"
#       end
#       it "status (add_status)" do
#         @request.host = "foo2.freshpo.com"
#         @request.env["HTTP_ACCEPT"] = "application/json"
#         @request.env["RAW_POST_DATA"]  = {"object"=>"page", "entry"=>[{"id"=>"532218423476440", "time"=>1369716171, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"status", "verb"=>"add", "post_id"=>"532218423476440_579757525389196"}}]}]}.to_json
#         Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns({"id"=>"532218423476440_579757525389196", "updated_time"=>"2013-05-28T04:42:51+0000", "message"=>"hello", "type"=>"status", "actions"=>[{"link"=>"http://www.facebook.com/532218423476440/posts/579757525389196", "name"=>"Comment"}, {"link"=>"http://www.facebook.com/532218423476440/posts/579757525389196", "name"=>"Like"}], "from"=>{"id"=>"5322184234764401", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}, "created_time"=>"2013-05-28T04:42:51+0000", "status_type"=>"mobile_status_update", "privacy"=>{"deny"=>"", "value"=>"EVERYONE", "friends"=>"", "allow"=>"", "networks"=>"", "description"=>"Public"}})
#         post 'subscription'
#         Helpdesk::Ticket.all.size.should eql 1
#         response.body.should eql "Thanks for the update"
#       end
#     end

#     context "should not create a ticket when status is updated" do
#       it "post (add_status)" do
#         @request.host = "foo2.freshpo.com"
#         @request.env["HTTP_ACCEPT"] = "application/json"
#         @request.env["RAW_POST_DATA"]  = {"object"=>"page", "entry"=>[{"id"=>"532218423476440", "time"=>1369716171, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"status", "verb"=>"add", "post_id"=>"532218423476440_579757525389196"}}]}]}.to_json
#         Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns({"id"=>"532218423476440_579757525389196", "updated_time"=>"2013-05-28T04:42:51+0000", "message"=>"hello", "type"=>"status", "actions"=>[{"link"=>"http://www.facebook.com/532218423476440/posts/579757525389196", "name"=>"Comment"}, {"link"=>"http://www.facebook.com/532218423476440/posts/579757525389196", "name"=>"Like"}], "from"=>{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}, "created_time"=>"2013-05-28T04:42:51+0000", "status_type"=>"mobile_status_update", "privacy"=>{"deny"=>"", "value"=>"EVERYONE", "friends"=>"", "allow"=>"", "networks"=>"", "description"=>"Public"}})
#         post 'subscription'
#         Helpdesk::Ticket.all.size.should eql 0
#         response.body.should eql "Thanks for the update"
#       end
#     end

#     context "should create a note from a comment " do
#       it "add comment to a status" do
#         @request.host = "foo2.freshpo.com"
#         @request.env["HTTP_ACCEPT"] = "application/json"
#         @request.env["RAW_POST_DATA"]  = {"object"=>"page", "entry"=>[{"id"=>"532218423476440", "time"=>1369716171, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"status", "verb"=>"add", "post_id"=>"532218423476440_579757525389196"}}]}]}.to_json
#         Koala::Facebook::GraphAndRestAPI.any_instance.expects(:get_object).returns({"id"=>"532218423476440_579757525389196", "updated_time"=>"2013-05-28T04:42:51+0000", "message"=>"hello", "type"=>"status", "actions"=>[{"link"=>"http://www.facebook.com/532218423476440/posts/579757525389196", "name"=>"Comment"}, {"link"=>"http://www.facebook.com/532218423476440/posts/579757525389196", "name"=>"Like"}], "from"=>{"id"=>"5322184234764401", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}, "created_time"=>"2013-05-28T04:42:51+0000", "status_type"=>"mobile_status_update", "privacy"=>{"deny"=>"", "value"=>"EVERYONE", "friends"=>"", "allow"=>"", "networks"=>"", "description"=>"Public"}})
#         post 'subscription'
#         Helpdesk::Ticket.all.size.should eql 1
#         @request.env["RAW_POST_DATA"] = {"object"=>"page", "entry"=>[{"id"=>"532218423476440", "time"=>1369719722, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"comment", "verb"=>"add", "comment_id"=>"579757525389196_6955346", "parent_id"=>579757525389196, "sender_id"=>100005815842768, "created_time"=>1369719722}}]}]}.to_json
#         Koala::Facebook::GraphAndRestAPI.any_instance.expects(:get_object).returns({"id"=>"579757525389196_6955346", "message"=>"yes", "can_remove"=>true, "like_count"=>0, "user_likes"=>false, "from"=>{"id"=>"100005815842768", "name"=>"Richardo Paul"}, "created_time"=>"2013-05-28T05:42:01+0000"})
#         post 'subscription'
#         Helpdesk::Ticket.last.notes.size.should eql 1
#         response.body.should eql "Thanks for the update"
#       end
#     end
#   end
# end
