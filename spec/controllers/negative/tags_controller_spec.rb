require 'spec_helper'

describe Helpdesk::TagsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @group = create_group(@account, {:name => "NegativeAccount"})
    @ticket1 = create_ticket({ :status => 2}, @group)
    @tag1=@ticket1.tags.create(:name=> "TagA - #{Faker::Name.name}", :account_id =>@account.id)
    @ticket2 = create_ticket({ :status => 2}, @group)
    @tag2=@ticket2.tags.create(:name=> "TagB - #{Faker::Name.name}", :account_id =>@account.id)
    @tag3=@ticket2.tags.create(:name=> "TagC - #{Faker::Name.name}", :account_id =>@account.id)
    @ticket3 = create_ticket({ :status => 2}, @group)
    @tag3=@ticket3.tags.create(:name=> "TagD - #{Faker::Name.name}", :account_id =>@account.id)
    @user_negative = add_new_user(@account)
  end

  before(:each) do
    log_in(@user_negative)
  end

  it "should not go to index page" do
    get 'index'
    response.should_not render_template "helpdesk/tags/index"
    response.body.should =~ /redirected/
  end

  it "should not show sorted tags" do
    get 'index' ,:sort=>"name_asc"
    response.should_not render_template "helpdesk/tags/_sort_results"
  end

  it "should not rename the tag" do
    tag_name="Tag1 - #{Faker::Name.name}"
    put 'rename_tags' , :tag_id => @tag1.id,:tag_name => tag_name
    @account.tags.find_by_id(@tag1.id).name.should_not be_eql(tag_name)
  end

  it "should not merge the tags" do
    put 'merge_tags', :tag_id => @tag1.id,:tag_name =>@tag2.name
    @account.tags.find_by_id(@tag1.id).should_not be_nil
  end

  it "should not remove associated tags" do
    delete :remove_tag, :tag_id=>@tag3.id, :tag_type=> "Helpdesk::Ticket"
    @account.tags.find_by_id(@tag3.id).tag_uses_count.should_not be_eql(0)
  end

end
