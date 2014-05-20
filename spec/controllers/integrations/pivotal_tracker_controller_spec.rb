require 'spec_helper'

describe Integrations::PivotalTrackerController do
	setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
    new_application = Factory.build(:application, :name => "pivotal_tracker",
                                    :display_name => "pivotal_tracker", 
                                    :listing_order => 23, 
                                    :options => {
																        :keys_order => [:api_key, :pivotal_update], 
																        :api_key => { :type => :text, :required => true, :label => "integrations.pivotal_tracker.api_key", :info => "integrations.pivotal_tracker.api_key_info"},
																        :pivotal_update => { :type => :checkbox, :label => "integrations.pivotal_tracker.pivotal_updates"}
																    },
                                    :application_type => "pivotal_tracker")
    new_application.save(false)

    new_installed_application = Factory.build(:installed_application, :application_id => "23",
                                              :account_id => @account.id, 
                                              :configs => { :inputs => { :api_key => "f7e85279afcce3b6f9db71bae15c8b69", :pivotal_update => 1} }
                                              )
    new_installed_application.save(false)

  end

   before(:each) do
    log_in(@user)
  end

  it "should get pivotal updates" do
    data = {
    "changes"=> [
        {
            "kind"=> "story",
            "original_values"=> {
                "story_type"=> "feature",
                "updated_at"=> 1397135627000
            },
            "story_type"=> "chore",
            "change_type"=> "update",
            "new_values"=> {
                "story_type"=> "chore",
                "updated_at"=> 1397135925000
            },
            "id"=> 69259422,
            "name"=> "This is a sample ticket"
        }
      ],
      "message"=> "sathish edited this chore",
      "kind"=> "story_update_activity",
      "guid"=> "1039530_26",
      "performed_by"=> {
          "kind"=> "person",
          "initials"=> "SA",
          "id"=> 1282144,
          "name"=> "sathish"
      },
      "primary_resources"=> [
          {
              "kind"=> "story",
              "story_type"=> "chore",
              "url"=> "http=>//www.pivotaltracker.com/story/show/69259422",
              "id"=> 69259422,
              "name"=> "This is a sample ticket"
          }
      ],
      "occurred_at"=> 1397135925000,
      "highlight"=> "edited",
      "project_version"=> 26,
      "project"=> {
          "kind"=> "project",
          "id"=> 1039530,
          "name"=> "freshdesk"
      }
    }

    installed_app = @account.installed_applications.with_name("pivotal_tracker").first
    if installed_app && installed_app["configs"][:inputs]["pivotal_update"] == "1"
      case data["kind"].to_sym
       when :story_update_activity
        changes = "story updated "
       when :story_delete_activity
        changes = "story deleted"
       when :task_create_activity
        changes = "other activites"
      end
      post :pivotal_updates, { :helpdesk_note => { :body_html => "<div>#{changes}</div>", 
                                     :user_id => @user.id, 
                                     :private => true, 
                                     :source => "2" 
                                     },
                    :ticket_id => @test_ticket.display_id
                  }
      @test_note = @account.tickets.find(@test_ticket.id).notes
      @test_note.body_html.should be_eql("<div>#{changes}</div>")
    end
    
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
                                     :user_id => @user.id, 
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

