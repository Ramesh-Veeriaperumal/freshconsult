require 'spec_helper'
describe Integrations::PivotalTrackerController do
	setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
    new_application = FactoryGirl.build(:application, :name => "pivotal_tracker",
                                    :display_name => "pivotal_tracker",
                                    :listing_order => 23,
                                    :options => {
																        :keys_order => [:api_key, :pivotal_update],
																        :api_key => { :type => :text, :required => true, :label => "integrations.pivotal_tracker.api_key", :info => "integrations.pivotal_tracker.api_key_info"},
																        :pivotal_update => { :type => :checkbox, :label => "integrations.pivotal_tracker.pivotal_updates"}
																    },
                                    :application_type => "pivotal_tracker")
    new_application.save(:validate => false)

    new_installed_application = FactoryGirl.build(:installed_application, :application_id => new_application.id,
                                              :account_id => @account.id,
                                              :configs => { :inputs => { 'api_key' => "c599b57edad0cb430d6fbf2543450c6c", "pivotal_update" => "1"} }
                                              )
    @new_installed = new_installed_application.save(:validate => false)
    integrated_res = FactoryGirl.build(:integrated_resource, :installed_application_id => new_installed_application.id,
                    :remote_integratable_id => "1106038/stories/73687832", :local_integratable_id => @test_ticket.display_id,
                    :local_integratable_type => "issue-tracking", :account_id => @account.id)
    resp = integrated_res.save!
    @response = { :pivotal_message => "success"}
  end

  before(:each) do
    login_admin
  end

  it "should get tickets" do 
    get :tickets, {}
    response.should_not be_nil
  end

  it "should get pivotal updates for story update" do
    @request.env['RAW_POST_DATA'] = "{\"kind\":\"story_update_activity\",\"guid\":\"1106038_5\",\"project_version\":5,
    \"message\":\"aravind edited this bug\",\"highlight\":\"edited\",\"changes\":[{\"kind\":\"story\",
    \"change_type\":\"update\",\"id\":73670796,\"original_values\":{\"story_type\":\"feature\",\"updated_at\":1403427507000},
    \"new_values\":{\"story_type\":\"bug\",\"updated_at\":1403427592000},\"name\":\"This is a sample ticket\",
    \"story_type\":\"bug\"}],\"primary_resources\":[{\"kind\":\"story\",\"id\":73670796,\"name\":\"This is a sample ticket\",
    \"story_type\":\"bug\",\"url\":\"https://www.pivotaltracker.com/story/show/73670796\"}],\"project\":{\"kind\":\"project\",
    \"id\":1106038,\"name\":\"asd\"},\"performed_by\":{\"kind\":\"person\",\"id\":1321296,\"name\":\"aravind\",\"initials\":\"AR\"},\"occurred_at\":1403427592000}"
    post :pivotal_updates, {}, 'CONTENT_TYPE' => "application/json"
    response.should eql @response
  end

  it "should get pivotal updates for story move into project " do
    @request.env['RAW_POST_DATA'] = "{\"kind\":\"story_move_into_project_activity\",\"guid\":\"1106038_13\",
    \"project_version\":13,\"message\":\"aravind moved \\\"qijeiqjweq\\\" into this project from Test\",
    \"highlight\":\"moved\",\"changes\":[{\"kind\":\"story\",\"change_type\":\"create\",\"id\":73687832,
    \"new_values\":{\"id\":73687832,\"project_id\":1106038,\"name\":\"qijeiqjweq\",
    \"description\":\"Ticket ID - 1\\n\\nRequester Email - rachel@freshdesk.com\\n\\nDescription - This is a sample ticket, feel free to delete it.\",
    \"story_type\":\"feature\",\"current_state\":\"unscheduled\",\"requested_by_id\":1321296,\"owner_ids\":[],
    \"label_ids\":[],\"follower_ids\":[],\"created_at\":1403503529000,\"updated_at\":1403503569000,\"before_id\":73545130,
    \"labels\":[]},\"name\":\"qijeiqjweq\",\"story_type\":\"feature\"}],\"primary_resources\":[{\"kind\":\"story\",
    \"id\":73687832,\"name\":\"qijeiqjweq\",\"story_type\":\"feature\",\"url\":\"https://www.pivotaltracker.com/story/show/73687832\"}],
    \"project\":{\"kind\":\"project\",\"id\":1106038,\"name\":\"asd\"},\"performed_by\":{\"kind\":\"person\",\"id\":1321296,
    \"name\":\"aravind\",\"initials\":\"AR\"},\"occurred_at\":1403503569000}"
    post :pivotal_updates, {}, 'CONTENT_TYPE' => "application/json"
    response.should eql @response
  end




  it "should get pivotal updates for task create" do
    @request.env['RAW_POST_DATA'] = "{\"kind\":\"task_create_activity\",\"guid\":\"1106038_7\",\"project_version\":7,
    \"message\":\"aravind added task: \\\"testing\\\"\",\"highlight\":\"added task:\",\"changes\":[{\"kind\":\"task\",
    \"change_type\":\"create\",\"id\":23254994,\"new_values\":{\"id\":23254994,\"story_id\":73670796,\"description\":\"testing\",
    \"complete\":false,\"position\":2,\"created_at\":1403503234000,\"updated_at\":1403503234000}},{\"kind\":\"story\",
    \"change_type\":\"update\",\"id\":73670796,\"original_values\":{\"updated_at\":1403503158000},\"new_values\":{\"updated_at\":1403503234000},
    \"name\":\"This is a sample ticket\",\"story_type\":\"bug\"}],\"primary_resources\":[{\"kind\":\"story\",
    \"id\":73670796,\"name\":\"This is a sample ticket\",\"story_type\":\"bug\",\"url\":\"https://www.pivotaltracker.com/story/show/73670796\"}],
    \"project\":{\"kind\":\"project\",\"id\":1106038,\"name\":\"asd\"},\"performed_by\":{\"kind\":\"person\",\"id\":1321296,
    \"name\":\"aravind\",\"initials\":\"AR\"},\"occurred_at\":1403503234000}"
    post :pivotal_updates, {}, 'CONTENT_TYPE' => "application/json"
    response.should eql @response
  end

  it "should get pivotal updates for task delete" do
    @request.env['RAW_POST_DATA'] = "{\"kind\":\"task_delete_activity\",\"guid\":\"1106038_11\",\"project_version\":11,
    \"message\":\"aravind deleted a task on this story\",\"highlight\":\"deleted a task\",\"changes\":[{\"kind\":\"story\",
    \"change_type\":\"update\",\"id\":73670796,\"original_values\":{\"updated_at\":1403503336000},\"new_values\":{\"updated_at\":1403503364000},
    \"name\":\"This is a sample ticket\",\"story_type\":\"bug\"},{\"kind\":\"task\",\"change_type\":\"delete\",\"id\":23254988}],
    \"primary_resources\":[{\"kind\":\"story\",\"id\":73670796,\"name\":\"This is a sample ticket\",\"story_type\":\"bug\",
    \"url\":\"https://www.pivotaltracker.com/story/show/73670796\"}],\"project\":{\"kind\":\"project\",\"id\":1106038,
    \"name\":\"asd\"},\"performed_by\":{\"kind\":\"person\",\"id\":1321296,\"name\":\"aravind\",\"initials\":\"AR\"},
    \"occurred_at\":1403503364000}"
    post :pivotal_updates, {}, 'CONTENT_TYPE' => "application/json"
    response.should eql @response
  end

  it "should get pivotal updates for story move from project " do
    @request.env['RAW_POST_DATA'] = "{\"kind\":\"story_move_from_project_activity\",\"guid\":\"1106038_12\",
    \"project_version\":12,\"message\":\"aravind moved \\\"This is a sample ticket\\\" from this project to Test\",
    \"highlight\":\"moved\",\"changes\":[{\"kind\":\"story\",\"change_type\":\"delete\",\"id\":73670796,
    \"name\":\"This is a sample ticket\",\"story_type\":\"bug\"}],\"primary_resources\":[{\"kind\":\"story\",
    \"id\":73670796,\"name\":\"This is a sample ticket\",\"story_type\":\"bug\",\"url\":\"https://www.pivotaltracker.com/story/show/73670796\"}],
    \"project\":{\"kind\":\"project\",\"id\":1106038,\"name\":\"asd\"},\"performed_by\":{\"kind\":\"person\",
    \"id\":1321296,\"name\":\"aravind\",\"initials\":\"AR\"},\"occurred_at\":1403503476000}"
    post :pivotal_updates, {}, 'CONTENT_TYPE' => "application/json"
    response.should eql @response
  end

  it "should get pivotal updates for story delete" do
    @request.env['RAW_POST_DATA'] = "{\"kind\":\"story_delete_activity\",\"guid\":\"1106038_14\",\"project_version\":14,
    \"message\":\"aravind deleted this feature\",\"highlight\":\"deleted\",\"changes\":[{\"kind\":\"story\",
    \"change_type\":\"delete\",\"id\":73687832,\"name\":\"qijeiqjweq\",\"story_type\":\"feature\"}],
    \"primary_resources\":[{\"kind\":\"story\",\"id\":73687832,\"name\":\"qijeiqjweq\",\"story_type\":\"feature\",
    \"url\":\"https://www.pivotaltracker.com/story/show/73687832\"}],\"project\":{\"kind\":\"project\",\"id\":1106038,
    \"name\":\"asd\"},\"performed_by\":{\"kind\":\"person\",\"id\":1321296,\"name\":\"aravind\",\"initials\":\"AR\"},
    \"occurred_at\":1403504442000}"
    post :pivotal_updates, {}, 'CONTENT_TYPE' => "application/json"
    response.should eql @response
  end


  it "should update installed application" do
  	installed_app = @account.installed_applications.with_name("pivotal_tracker").first
  	installed_app["configs"][:inputs]["webhooks_applicationid"] = [] unless installed_app["configs"][:inputs].include? "webhooks_applicationid"
    unless installed_app["configs"][:inputs]["webhooks_applicationid"].include? 1234
      installed_app["configs"][:inputs]["webhooks_applicationid"].push(12345)
      installed_app.save!
    end
  	data = "Story created"
    post :update_config, { :helpdesk_note =>  {:body_html => "<div>#{data}</div>",
                                     :user_id => @agent.id,
                                     :private => true,
                                     :source => "2"
                                     },
                    :ticket_id => @test_ticket.display_id
                  }
  end

  it "should add integrated resource" do
    post :update_config, { "application_id" => 23, :integrated_resource => { :local_integratable_id => @test_ticket.id,
             :remote_integratable_id => "10234/stories/19484",
             :local_integratable_type => "issue-tracking", :account => @account }

              }
  end
end
