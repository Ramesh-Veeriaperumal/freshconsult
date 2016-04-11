require 'spec_helper'

describe Helpdesk::TagsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @group = create_group(@account, {:name => "Merge"})
    @ticket1 = create_ticket({ :status => 2}, @group)
    @tag1=@ticket1.tags.create(:name=> "TagA - #{Faker::Name.name}", :account_id =>@account.id)
    @ticket2 = create_ticket({ :status => 2}, @group)
    @tag2=@ticket2.tags.create(:name=> "TagB - #{Faker::Name.name}", :account_id =>@account.id)
    @tag3=@ticket2.tags.create(:name=> "TagC - #{Faker::Name.name}", :account_id =>@account.id)
    @ticket3 = create_ticket({ :status => 2}, @group)
    @tag3=@ticket3.tags.create(:name=> "TagD - #{Faker::Name.name}", :account_id =>@account.id)
  end

  before(:each) do
    log_in(@agent)
  end

  it "should go to index page" do
    get 'index'
    response.should render_template "helpdesk/tags/index"
    response.body.should =~ /Manage Tags/
  end


  it "should show sorted tags" do
    get 'index' ,:sort=>"name_asc"
    response.should render_template "helpdesk/tags/_sort_results"
  end

  it "should rename the tag" do
    tag_name="Tag1 - #{Faker::Name.name}"
    put 'rename_tags' , :tag_id => @tag1.id,:tag_name => tag_name
    @account.tags.find_by_id(@tag1.id).name.should be_eql(tag_name)
  end

  it "should merge the tags" do
    put 'merge_tags', :tag_id => @tag1.id,:tag_name =>@tag2.name
    @account.tags.find_by_id(@tag1.id).should be_nil
  end

  it "should remove associated tags" do
    delete :remove_tag, :tag_id=>@tag3.id, :tag_type=> "Helpdesk::Ticket"
    @account.tags.find_by_id(@tag3.id).tag_uses_count.should be_eql(0)
  end

  it "should complete tags search automatically" do
    t=@account.tags.where("name like ?","tag%")
    r={:results=>t.map{|i| {:id=> i.to_param,:value => i.send("name")}}}.to_json
    get 'autocomplete', :v=>"tag", :format => :json
    response.body.should =~/r/
  end

end
