require 'spec_helper'

RSpec.configure do |c|
  c.include GnipHelper
  c.include DynamoHelper
  c.include Social::Twitter::Constants
  #c.include Social::Dynamo::Twitter
  c.include Social::Util
end

RSpec.describe Admin::Social::TwitterStreamsController do
  setup :activate_authlogic
  
  self.use_transactional_fixtures = false
  
  before(:all) do
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      GnipRule::Client.any_instance.stubs(:add).returns(add_response)
    end
    @handle = create_test_twitter_handle(@account)
    @default_stream = @handle.default_stream
    @custom_stream = create_test_custom_twitter_stream(@handle)
    @data = @default_stream.data
    update_db(@default_stream) unless GNIP_ENABLED
    @rule = {:rule_value => @data[:rule_value], :rule_tag => @data[:rule_tag]}
    Resque.inline = false
    @new_stream = nil
  end
  
  before(:each) do
    login_admin
  end
  
  describe "GET #new" do
    it "should render the create stream page when create a new stream is clicked" do
      get :new
      response.should render_template("admin/social/twitter_streams/new") 
    end
  end
  
  describe "GET #edit" do
    it "should render the create stream page when create a new stream is clicked for global access type" do
      get :edit, {
        :id => @default_stream.id
      }
      response.should render_template("admin/social/twitter_streams/edit") 
    end
  end
  
  
  describe "GET #preview" do
    it "should show a preview of the feeds matching the filter criteria specified" do
      includes = Faker::Lorem.words(1)
      excludes = Faker::Lorem.words(1)
      Twitter::REST::Client.any_instance.stubs(:search).returns(sample_search_results_object)
      
      get :preview, {
        :includes => includes,
        :excludes => excludes,
        :exclude_handles => ""
      }  
    end
  end
  
  describe "POST #create" do
    it "should create a new twitter stream of type custom and create it's helpdesk access" do
      stream_name = "#{Faker::Lorem.words(1)}"
      includes = Faker::Lorem.words(1)
      excludes = Faker::Lorem.words(1)
      
      post :create, {
                      :twitter_stream =>
                        {
                          :name => "#{stream_name}", 
                          :includes => includes, 
                          :excludes => excludes, 
                          :filter => "", 
                          :social_id => ""
                        }, 
                      :social_twitter_stream => 
                        {
                          :product_id => "Default product"
                        },
                        :visible_to => ["2"], 
                        :social_ticket_rule => 
                        [
                          {
                            :ticket_rule_id => "",
                            :deleted => "false",
                            :includes => "Ticket Rule Includes", 
                            :group_id => "...", 
                            }
                        ]
                      }
      new_stream  = Social::TwitterStream.find_by_name(stream_name)
      new_stream[:includes].should eql(includes)
      new_stream[:excludes].should eql(excludes)
      new_stream.custom_stream?.should be_truthy
      new_stream.ticket_rules.should_not be_nil
      ticket_rule = new_stream.ticket_rules.first
      new_stream.accessible.should_not be_nil
      flash[:notice].should =~ /Twitter Stream has been created successfully/
      @custom_stream = new_stream
    end
  end
  
  
  describe "PUT #update" do
    it "should update a default handle" do
      
      put :update, {
                      :id => @default_stream.id,
                      :social_twitter_handle => {
                        :product_id => "Default Product",
                        :dm_thread_time => "0"
                      },
                      :dm_rule => 
                      {
                        :group_assigned => "2"
                      },
                      :twitter_stream =>
                        {
                          :name => @default_stream.name, 
                          :includes => "", 
                          :excludes => @default_stream[:excludes], 
                          :filter => "", 
                          :social_id => ""
                        }, 
                        :visible_to => ["2"], 
                        :social_ticket_rule => 
                        []
                      }
                      
      @default_stream.ticket_rules.count.should eql(0)
      @handle.dm_thread_time.should eql(86400)
      @handle.dm_stream.ticket_rules.first.action_data[:group_id].should eql(2)
      @default_stream.accessible[:access_type].should eql(2)
    end
    
    it "should render the create stream page when create a new stream is clicked for group access type" do
      get :edit, {
        :id => @default_stream.id
      }
      response.should render_template("admin/social/twitter_streams/edit") 
    end
    

    it "should update a stream create/delete ticket rules if the includes is not empty and remove rules of deleted" do    
      stream_name = "#{Faker::Lorem.words(1)}"
      includes = Faker::Lorem.words(1)
      excludes = Faker::Lorem.words(1)
      post :create, {
                      :twitter_stream =>
                        {
                          :name => "#{stream_name}", 
                          :includes => includes, 
                          :excludes => excludes, 
                          :filter => "", 
                          :social_id => ""
                        }, 
                        :social_twitter_stream => 
                          {
                            :product_id => "Default product"
                          },
                        :visible_to => ["0"], 
                        :social_ticket_rule => 
                        [
                          {
                            :ticket_rule_id => "",
                            :deleted => "false",
                            :includes => ["Ticket rule includes"], 
                            :group_id => "...", 
                          },
                          {
                            :ticket_rule_id => "",
                            :deleted => "false",
                            :includes => ["Ticket rule includes2"], 
                            :group_id => "...", 
                          }
                        ]
                      }
      new_stream  = Social::TwitterStream.find_by_name(stream_name)
      ticket_rule1 = new_stream.ticket_rules.first
      ticket_rule2 = new_stream.ticket_rules.second
      
      stream_name = "#{Faker::Lorem.words(1)}"
      includes = Faker::Lorem.words(1)
      excludes = Faker::Lorem.words(1)
      put :update, {
                      :id => new_stream.id,
                      :social_twitter_stream => 
                        {
                          :product_id => "Default product"
                        },
                      :twitter_stream =>
                        {
                          :name => new_stream.name, 
                          :includes => new_stream[:includes], 
                          :excludes => new_stream[:excludes], 
                          :filter => "", 
                          :social_id => ""
                        }, 
                        :visible_to => ["0", "1"], 
                        :social_ticket_rule => 
                        [
                          {
                            :ticket_rule_id => "#{ticket_rule1.id}",
                            :deleted => "true",
                            :includes => ["Ticket rule includes"], 
                            :group_id => "...", 
                          },
                          {
                            :ticket_rule_id => "#{ticket_rule2.id}",
                            :includes => ["Ticket rule updated"], 
                            :group_id => "...", 
                          },
                          {
                            :ticket_rule_id => "",
                            :deleted => "false",
                            :includes => ["Ticket rule includes new"], 
                            :group_id => "...", 
                          },
                          {
                            :ticket_rule_id => "",
                            :deleted => "false",
                            :includes => "" , 
                            :group_id => "1", 
                          },
                          {
                            :ticket_rule_id => "",
                            :deleted => "true",
                            :includes => ["New Ticket rule"], 
                            :group_id => "...", 
                          }
                        ]
                      }
                      
      new_stream.reload
      new_stream.ticket_rules.count.should eql(2)
      new_stream.ticket_rules.first[:filter_data][:includes].should eql(["Ticket rule updated"])
    end
  end
  
  describe "PUT #update" do
    it "should delete the custom stream" do
      delete :destroy, {
        :id => @custom_stream.id
      }
      Social::Stream.find_by_id(@custom_stream.id).should be_nil
    end
  end
    
  after(:all) do
    #Destroy the twitter handle
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      GnipRule::Client.any_instance.stubs(:delete).returns(delete_response) 
    end
    # @handle.destroy
    # Social::Stream.destroy_all
    # Social::Tweet.destroy_all
    Resque.inline = false
  end
  
end
