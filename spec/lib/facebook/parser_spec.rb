require File.expand_path("#{File.dirname(__FILE__)}/../../spec_helper")
describe Facebook::Core::Parser do
  before(:all) do
    @account = create_test_account
    @account.make_current
    ShardMapping.find_by_account_id(@account.id).update_attribute(:status,200)
    Social::FacebookPage.any_instance.stubs(:after_commit_on_create => true)
    Social::FacebookPage.any_instance.stubs(:after_commit_on_update => true)
    # FBClient.any_instance.stubs(:subscribe_for_page).returns(true)
    # Social::FacebookPosts.any_instance.stubs(:fetch).returns({})
    fb_page = Factory.build(:facebook_pages)
    fb_page.account_id = @account.id
    fb_page.save(false)
  end

  after(:each) do
    Helpdesk::Ticket.destroy_all
    Helpdesk::Note.destroy_all
  end

  after(:all) do
    # FBClient.any_instance.stubs(:subscribe_for_page).returns(true)
    # Social::FacebookPosts.any_instance.stubs(:fetch).returns({})
    # Social::FacebookPage.destroy_all
    Social::FacebookPage.destroy_all
    User.destroy_all
    UserEmail.destroy_all
  end

  describe "parse status" do
    it "create a ticket" do
      Social::FacebookPage.first.update_attribute(:import_company_posts,true)
      json_data = {"entry"=>{"id"=>"532218423476440", "time"=>1374146491, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"status", "verb"=>"add", "post_id"=>"532218423476440_603468519684763"}}]}}.to_json
      #stub the api call for koala
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns({"type"=>"status", "privacy"=>{"value"=>""}, "actions"=>[{"name"=>"Comment", "link"=>"https://www.facebook.com/532218423476440/posts/603468519684763"}, {"name"=>"Like", "link"=>"https://www.facebook.com/532218423476440/posts/603468519684763"}], "from"=>{"name"=>"Causeeeeeeeadded", "id"=>"532218423476440", "category"=>"Cause"}, "created_time"=>"2013-07-18T11:24:08+0000", "id"=>"532218423476440_603468519684763", "updated_time"=>"2013-07-18T11:24:08+0000", "message"=>"second status update by page owner", "status_type"=>"mobile_status_update"})
      Facebook::Core::Parser.new(json_data).parse
      Helpdesk::Ticket.all.size.should eql 1
      ticket = Helpdesk::Ticket.first
      ticket.description.should eql "second status update by page owner"
      ticket.description_html.should eql "<div>second status update by page owner</div>"
      ticket.subject.should eql "second status update by page owner"
      ticket.requester.name.should eql "Causeeeeeeeadded"
    end

    it "create both ticket and note" do
      Social::FacebookPage.first.update_attribute(:import_company_posts,true)
      json_data = { "entry"=>{"id"=>"532218423476440", "time"=>1374146491, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"status", "verb"=>"add", "post_id"=>"532218423476440_603467883018160"}}]}}.to_json
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns({"message"=>"status update by page owner", "comments"=>{"paging"=>{"cursors"=>{"after"=>"MQ==", "before"=>"Mw=="}}, "data"=>[{"user_likes"=>false, "can_remove"=>true, "message"=>"not getting the updates anything wrong..", "from"=>{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}, "like_count"=>0, "created_time"=>"2013-07-18T11:31:57+0000", "id"=>"603467883018160_7126761"}, {"user_likes"=>false, "can_remove"=>true, "message"=>"data", "from"=>{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}, "like_count"=>0, "created_time"=>"2013-07-18T13:10:56+0000", "id"=>"603467883018160_7127048"}, {"user_likes"=>false, "can_remove"=>true, "message"=>"comment to my first status", "from"=>{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}, "like_count"=>0, "created_time"=>"2013-07-18T11:29:35+0000", "id"=>"603467883018160_7126756"}]}, "status_type"=>"mobile_status_update", "type"=>"status", "actions"=>[{"link"=>"https://www.facebook.com/532218423476440/posts/603467883018160", "name"=>"Comment"}, {"link"=>"https://www.facebook.com/532218423476440/posts/603467883018160", "name"=>"Like"}], "privacy"=>{"value"=>"EVERYONE", "allow"=>"", "friends"=>"", "deny"=>"", "networks"=>"", "description"=>"Public"}, "from"=>{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}, "updated_time"=>"2013-07-18T13:10:56+0000", "created_time"=>"2013-07-18T11:21:31+0000", "id"=>"532218423476440_603467883018160"})
      Facebook::Core::Parser.new(json_data).parse
      Helpdesk::Ticket.all.size.should eql 1
      Helpdesk::Note.all.size.should eql 3
      all_notes = Helpdesk::Ticket.first.notes
      first_note = all_notes[0]
      second_note = all_notes[1]
      third_note = all_notes[2]
      first_note.body.should eql "not getting the updates anything wrong.."
      second_note.body.should eql "data"
      third_note.body.should eql "comment to my first status"
      first_note.body_html.should eql "<div>not getting the updates anything wrong..</div>"
      second_note.body_html.should eql "<div>data</div>"
      third_note.body_html.should eql "<div>comment to my first status</div>"
      first_note.user.name.should eql "Causeeeeeeeadded"
      second_note.user.name.should eql "Causeeeeeeeadded"
      third_note.user.name.should eql "Causeeeeeeeadded"
    end

    it "don't create a ticket" do
      json_data = {"entry"=>{"id"=>"532218423476440", "time"=>1374146491, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"status", "verb"=>"add", "post_id"=>"532218423476440_603468519684763"}}]}}.to_json
      #stub the api call for koala
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns({"type"=>"status", "privacy"=>{"value"=>""}, "actions"=>[{"name"=>"Comment", "link"=>"https://www.facebook.com/532218423476440/posts/603468519684763"}, {"name"=>"Like", "link"=>"https://www.facebook.com/532218423476440/posts/603468519684763"}], "from"=>{"name"=>"Causeeeeeeeadded", "id"=>"532218423476440", "category"=>"Cause"}, "created_time"=>"2013-07-18T11:24:08+0000", "id"=>"532218423476440_603468519684763", "updated_time"=>"2013-07-18T11:24:08+0000", "message"=>"second status update by page owner", "status_type"=>"mobile_status_update"})
      Facebook::Core::Parser.new(json_data).parse
      Helpdesk::Ticket.all.size.should eql 0
    end

    it "raise an api limit exception for koala and check if it is reenqueued into sqs" do
      Social::FacebookPage.first.update_attribute(:import_company_posts,true)
      json_data = {"entry"=>{"id"=>"532218423476440", "time"=>1374146491, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"status", "verb"=>"add", "post_id"=>"532218423476440_603468519684763"}}]}}.to_json
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).raises(Koala::Facebook::APIError.new("400",nil,"message is requeued"))
      Koala::Facebook::APIError.any_instance.stubs(:fb_error_type).returns(4)
      AwsWrapper::Sqs.any_instance.expects(:requeue).returns(true)
      Facebook::Core::Parser.new(json_data).parse   
      Social::FacebookPage.first.reauth_required.should be_false
    end

    it "authentication error check if it is pushed into dynamo db" do
      Social::FacebookPage.first.update_attribute(:import_company_posts,true)
      json_data = {"entry"=>{"id"=>"532218423476440", "time"=>1374146491, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"status", "verb"=>"add", "post_id"=>"532218423476440_603468519684763"}}]}}.to_json
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).raises(Koala::Facebook::APIError.new("400",nil,"message is pushed to dynamo db access token"))
      Koala::Facebook::APIError.any_instance.stubs(:fb_error_type).returns(190)
      AwsWrapper::DynamoDb.any_instance.expects(:write).returns(true)
      Facebook::Core::Parser.new(json_data).parse
      Social::FacebookPage.first.reauth_required.should be_true
    end

  end

  describe "parse post" do

    it "create a ticket" do
      json_data = {"entry"=>{"id"=>"532218423476440", "time"=>1374146359, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"post", "verb"=>"add", "post_id"=>603467223018226}}]}}.to_json
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns({"message"=>"this is a second post", "type"=>"status", "actions"=>[{"link"=>"https://www.facebook.com/532218423476440/posts/603467223018226", "name"=>"Comment"}, {"link"=>"https://www.facebook.com/532218423476440/posts/603467223018226", "name"=>"Like"}], "privacy"=>{"value"=>""}, "from"=>{"id"=>"100005115430108", "name"=>"Rikacho Paul"}, "updated_time"=>"2013-07-18T11:19:19+0000", "created_time"=>"2013-07-18T11:19:19+0000", "id"=>"532218423476440_603467223018226", "to"=>{"data"=>[{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}]}})
      Facebook::Core::Parser.new(json_data).parse
      Helpdesk::Ticket.all.size.should eql 1
      ticket = Helpdesk::Ticket.first
      ticket.requester.name.should eql "Rikacho Paul"
      ticket.description.should eql "this is a second post"
      ticket.description_html.should eql  "<div>this is a second post</div>"
      ticket.account_id.should_not be_nil
    end

    it "create both ticket and note" do
      json_data = {"entry"=>{"id"=>"532218423476440", "time"=>1374146272, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"post", "verb"=>"add", "post_id"=>603466913018257}}]}}.to_json
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns({"message"=>"this is a new post", "comments"=>{"paging"=>{"cursors"=>{"after"=>"MQ==", "before"=>"MQ=="}}, "data"=>[{"user_likes"=>false, "can_remove"=>true, "message"=>"commenting for new post", "from"=>{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}, "like_count"=>0, "created_time"=>"2013-07-18T11:26:39+0000", "id"=>"603466913018257_7126753"}]}, "type"=>"status", "actions"=>[{"link"=>"https://www.facebook.com/532218423476440/posts/603466913018257", "name"=>"Comment"}, {"link"=>"https://www.facebook.com/532218423476440/posts/603466913018257", "name"=>"Like"}], "privacy"=>{"value"=>""}, "from"=>{"id"=>"100005115430108", "name"=>"Rikacho Paul"}, "updated_time"=>"2013-07-18T11:26:39+0000", "created_time"=>"2013-07-18T11:17:52+0000", "id"=>"532218423476440_603466913018257", "to"=>{"data"=>[{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}]}})
      Facebook::Core::Parser.new(json_data).parse
      Helpdesk::Ticket.all.size.should eql 1
      ticket = Helpdesk::Ticket.first
      ticket.requester.name.should eql "Rikacho Paul"
      ticket.description.should eql "this is a new post"
      ticket.description_html.should eql  "<div>this is a new post</div>"
      ticket.account_id.should_not be_nil
      Helpdesk::Note.all.size.should eql 1
      note = Helpdesk::Ticket.first.notes.first
      note.body.should eql "commenting for new post"
      note.body_html.should eql "<div>commenting for new post</div>"
      note.user.name.should eql "Causeeeeeeeadded"
    end

    it "don't create a ticket" do
      Social::FacebookPage.first.update_attribute(:import_visitor_posts,false)
      json_data = {"entry"=>{"id"=>"532218423476440", "time"=>1374146359, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"post", "verb"=>"add", "post_id"=>603467223018226}}]}}.to_json
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns({"message"=>"this is a second post", "type"=>"status", "actions"=>[{"link"=>"https://www.facebook.com/532218423476440/posts/603467223018226", "name"=>"Comment"}, {"link"=>"https://www.facebook.com/532218423476440/posts/603467223018226", "name"=>"Like"}], "privacy"=>{"value"=>""}, "from"=>{"id"=>"100005115430108", "name"=>"Rikacho Paul"}, "updated_time"=>"2013-07-18T11:19:19+0000", "created_time"=>"2013-07-18T11:19:19+0000", "id"=>"532218423476440_603467223018226", "to"=>{"data"=>[{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}]}})
      Facebook::Core::Parser.new(json_data).parse
      Helpdesk::Ticket.all.size.should eql 0
    end

    it "raise an api limit exception for koala and check if it is reenqueued into sqs" do
      json_data = {"entry"=>{"id"=>"532218423476440", "time"=>1374146359, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"post", "verb"=>"add", "post_id"=>603467223018226}}]}}.to_json
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).raises(Koala::Facebook::APIError.new("400",nil,"message is requeued"))
      Koala::Facebook::APIError.any_instance.stubs(:fb_error_type).returns(4)
      AwsWrapper::Sqs.any_instance.expects(:requeue).returns(true)
      Facebook::Core::Parser.new(json_data).parse   
      Social::FacebookPage.first.reauth_required.should be_false
    end

    it "authentication error check if it is pushed into dynamo db" do
      json_data = {"entry"=>{"id"=>"532218423476440", "time"=>1374146359, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"post", "verb"=>"add", "post_id"=>603467223018226}}]}}.to_json
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).raises(Koala::Facebook::APIError.new("400",nil,"message is pushed to dynamo db access token"))
      Koala::Facebook::APIError.any_instance.stubs(:fb_error_type).returns(190)
      AwsWrapper::DynamoDb.any_instance.expects(:write).returns(true)
      Facebook::Core::Parser.new(json_data).parse
      Social::FacebookPage.first.reauth_required.should be_true
    end

  end

  describe "parse comment" do

    it "create comment when ticket is created" do
      json_data = {"entry"=>{"id"=>"532218423476440", "time"=>1374146359, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"post", "verb"=>"add", "post_id"=>603467223018226}}]}}.to_json
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns({"message"=>"this is a new post", "type"=>"status", "actions"=>[{"link"=>"https://www.facebook.com/532218423476440/posts/603466913018257", "name"=>"Comment"}, {"link"=>"https://www.facebook.com/532218423476440/posts/603466913018257", "name"=>"Like"}], "privacy"=>{"value"=>""}, "from"=>{"id"=>"100005115430108", "name"=>"Rikacho Paul"}, "updated_time"=>"2013-07-18T11:26:39+0000", "created_time"=>"2013-07-18T11:17:52+0000", "id"=>"532218423476440_603466913018257", "to"=>{"data"=>[{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}]}})
      Facebook::Core::Parser.new(json_data).parse
      Helpdesk::Ticket.all.size.should eql 1
      Helpdesk::Ticket.first.notes.size.should eql 0
      json_data = {"entry"=>{"id"=>"532218423476440", "time"=>1374146800, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"comment", "verb"=>"add", "comment_id"=>"603466913018257_7126753", "parent_id"=>603466913018257, "sender_id"=>532218423476440, "created_time"=>1374146800}}]}}.to_json
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns({"user_likes"=>false, "can_remove"=>true, "message"=>"commenting for new post", "from"=>{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}, "like_count"=>0, "created_time"=>"2013-07-18T11:26:39+0000", "id"=>"603466913018257_7126753"})
      Facebook::Core::Parser.new(json_data).parse
      Helpdesk::Ticket.all.size.should eql 1
      note = Helpdesk::Ticket.first.notes
      note.size.should eql 1
      note.first.user.name.should eql "Causeeeeeeeadded"
      note.first.body.should eql "commenting for new post"
    end

    it "create comment and ticket when ticket is not present" do
      json_data = {"entry"=>{"id"=>"532218423476440", "time"=>1374146800, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"comment", "verb"=>"add", "comment_id"=>"603466913018257_7126753", "parent_id"=>603466913018257, "sender_id"=>532218423476440, "created_time"=>1374146800}}]}}.to_json
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns({"message"=>"this is a new post", "comments"=>{"paging"=>{"cursors"=>{"after"=>"MQ==", "before"=>"MQ=="}}, "data"=>[{"user_likes"=>false, "can_remove"=>true, "message"=>"commenting for new post", "from"=>{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}, "like_count"=>0, "created_time"=>"2013-07-18T11:26:39+0000", "id"=>"603466913018257_7126753"}]}, "type"=>"status", "actions"=>[{"link"=>"https://www.facebook.com/532218423476440/posts/603466913018257", "name"=>"Comment"}, {"link"=>"https://www.facebook.com/532218423476440/posts/603466913018257", "name"=>"Like"}], "privacy"=>{"value"=>""}, "from"=>{"id"=>"100005115430108", "name"=>"Rikacho Paul"}, "updated_time"=>"2013-07-18T11:26:39+0000", "created_time"=>"2013-07-18T11:17:52+0000", "id"=>"532218423476440_603466913018257", "to"=>{"data"=>[{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}]}})
      Facebook::Core::Parser.new(json_data).parse
      Helpdesk::Ticket.all.size.should eql 1
      note = Helpdesk::Ticket.first.notes
      note.size.should eql 1
      note.first.user.name.should eql "Causeeeeeeeadded"
      note.first.body.should eql "commenting for new post"
    end

    it "don't create comment if the import visitor post is false" do
      Social::FacebookPage.first.update_attribute(:import_visitor_posts,false)
      json_data = {"entry"=>{"id"=>"532218423476440", "time"=>1374146800, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"comment", "verb"=>"add", "comment_id"=>"603466913018257_7126753", "parent_id"=>603466913018257, "sender_id"=>532218423476440, "created_time"=>1374146800}}]}}.to_json
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns({"message"=>"this is a new post", "comments"=>{"paging"=>{"cursors"=>{"after"=>"MQ==", "before"=>"MQ=="}}, "data"=>[{"user_likes"=>false, "can_remove"=>true, "message"=>"commenting for new post", "from"=>{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}, "like_count"=>0, "created_time"=>"2013-07-18T11:26:39+0000", "id"=>"603466913018257_7126753"}]}, "type"=>"status", "actions"=>[{"link"=>"https://www.facebook.com/532218423476440/posts/603466913018257", "name"=>"Comment"}, {"link"=>"https://www.facebook.com/532218423476440/posts/603466913018257", "name"=>"Like"}], "privacy"=>{"value"=>""}, "from"=>{"id"=>"100005115430108", "name"=>"Rikacho Paul"}, "updated_time"=>"2013-07-18T11:26:39+0000", "created_time"=>"2013-07-18T11:17:52+0000", "id"=>"532218423476440_603466913018257", "to"=>{"data"=>[{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}]}})
      Facebook::Core::Parser.new(json_data).parse
      Helpdesk::Ticket.all.size.should eql 0
      Helpdesk::Note.all.size.should eql 0
    end

    it "don't create comment if the import company post is false" do
      json_data = {"entry"=>{"id"=>"532218423476440", "time"=>1374146800, "changes"=>[{"field"=>"feed", "value"=>{"item"=>"comment", "verb"=>"add", "comment_id"=>"603466913018257_7126753", "parent_id"=>603466913018257, "sender_id"=>532218423476440, "created_time"=>1374146800}}]}}.to_json
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns({"message"=>"this is a new post", "comments"=>{"paging"=>{"cursors"=>{"after"=>"MQ==", "before"=>"MQ=="}}, "data"=>[{"user_likes"=>false, "can_remove"=>true, "message"=>"commenting for new post", "from"=>{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}, "like_count"=>0, "created_time"=>"2013-07-18T11:26:39+0000", "id"=>"603466913018257_7126753"}]}, "type"=>"status", "actions"=>[{"link"=>"https://www.facebook.com/532218423476440/posts/603466913018257", "name"=>"Comment"}, {"link"=>"https://www.facebook.com/532218423476440/posts/603466913018257", "name"=>"Like"}], "privacy"=>{"value"=>""}, "from"=>{"id"=>"532218423476440", "name"=>"Rikacho Paul"}, "updated_time"=>"2013-07-18T11:26:39+0000", "created_time"=>"2013-07-18T11:17:52+0000", "id"=>"532218423476440_603466913018257", "to"=>{"data"=>[{"id"=>"532218423476440", "category"=>"Cause", "name"=>"Causeeeeeeeadded"}]}})
      Facebook::Core::Parser.new(json_data).parse
      Helpdesk::Ticket.all.size.should eql 0
      Helpdesk::Note.all.size.should eql 0
    end

  end
end
