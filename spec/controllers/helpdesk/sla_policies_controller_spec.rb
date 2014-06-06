require 'spec_helper'

describe Helpdesk::SlaPoliciesController do
	integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@now = (Time.now.to_f*1000).to_i
		@agent_1 = add_test_agent(@account)
		@agent_2 = add_test_agent(@account)
		@sla_policy_1 = create_sla_policy(@agent_1)
		@sla_policy_2 = create_sla_policy(@agent_2) 
	end

	before(:each) do
		log_in(@agent)
	end

	it "should go to the Sla_policies index page" do
		get :index 
		response.body.should =~ /SLA Policies/
		response.should be_success
	end

	it "should create a new Sla Policy" do
		get :new
		response.body.should =~ /New SLA Policy/
		response.should be_success
		post :create, { 
			 :helpdesk_sla_policy =>{ :name =>"Sla Policy - Test Spec", 
			 	                      :id=>"", 
			 	                      :description => Faker::Lorem.paragraph,
			 	                      :datatype => {:ticket_type => "text"}, 
			 	                      :conditions =>{ :ticket_type =>["Question"], :company_id =>""}, 
			 	                      :escalations =>{:response=>{"1"=>{:time =>"0", :agents_id =>["#{@agent.id}"]}}, 
			 	                                      :resolution=>{"1"=>{:time=>"0", :agents_id=>["#{@agent_1.id}"]},
			 	                                                    "2"=>{:time=>"1800", :agents_id=>["#{@agent_2.id}"]}
			 	                                                }
			 	                                    }
			 	                      },
			 :SlaDetails =>{ "0"=> { :name=>"SLA for urgent priority", :priority=>"4", :id=>"", :response_time=>"900", :resolution_time=>"900", 
			 	                     :override_bhrs=>"false", :escalation_enabled=>"1"},
                             "1"=> { :name=>"SLA for high priority", :priority=>"3", :id=>"", :response_time=>"3600", :resolution_time=>"7200 ", 
                             	     :override_bhrs=>"false", :escalation_enabled=>"1"}, 
                             "2"=> { :name=>"SLA for medium priority", :priority=>"2", :id=>"", :response_time=>"86400", :resolution_time=>"172800", 
                             	     :override_bhrs=>"false", :escalation_enabled=>"1"},
							 "3"=> { :name=>"SLA for low priority", :priority=>"1", :id=>"", :response_time=>"2592000", :resolution_time=>"5184000", 
							 	     :override_bhrs=>"false", :escalation_enabled=>"1"}
							},
        }
        response.session[:flash][:notice].should eql "The SLA Policy has been created."
        sla_policy = Helpdesk::SlaPolicy.find_by_name("Sla Policy - Test Spec")
        sla_policy.should_not be_nil
        sla_policy.conditions[:ticket_type].should eql ["Question"]
        sla_policy.escalations[:response]["1"][:agents_id].should eql [@agent.id]
        sla_policy.escalations[:resolution]["2"][:time].should eql(1800)
        sla_details = Helpdesk::SlaDetail.find(:first,:conditions => [ "sla_policy_id = ? and priority = ?", sla_policy.id, 3 ])
        sla_details.resolution_time.should eql(7200)
        sla_details = Helpdesk::SlaDetail.find(:first,:conditions => [ "sla_policy_id = ? and priority = ?", sla_policy.id, 1 ])
        sla_details.response_time.should eql(2592000)
	end

	it "should not create a new Sla Policy without a name or conditions" do
		post :create, { 
			 :helpdesk_sla_policy =>{ :name =>"", 
			 	                      :id=>"", 
			 	                      :description => Faker::Lorem.paragraph,
			 	                      :datatype => {:ticket_type => "text"}, 
			 	                      :conditions =>{:company_id =>""}, 
			 	                      :escalations =>{:response=>{"1"=>{:time =>"0", :agents_id =>["#{@agent.id}"]}}, 
			 	                                      :resolution=>{"1"=>{:time=>"0", :agents_id=>["#{@agent_1.id}"]},
			 	                                                    "2"=>{:time=>"1800", :agents_id=>["#{@agent_2.id}"]}
			 	                                                }
			 	                                    }
			 	                      },
			 :SlaDetails =>{ "0"=> { :name=>"SLA for urgent priority", :priority=>"4", :id=>"", :response_time=>"900", :resolution_time=>"900", 
			 	                     :override_bhrs=>"false", :escalation_enabled=>"1"},
                             "1"=> { :name=>"SLA for high priority", :priority=>"3", :id=>"", :response_time=>"3600", :resolution_time=>"7200 ", 
                             	     :override_bhrs=>"false", :escalation_enabled=>"1"}, 
                             "2"=> { :name=>"SLA for medium priority", :priority=>"2", :id=>"", :response_time=>"86400", :resolution_time=>"172800", 
                             	     :override_bhrs=>"false", :escalation_enabled=>"1"},
							 "3"=> { :name=>"SLA for low priority", :priority=>"1", :id=>"", :response_time=>"2592000", :resolution_time=>"5184000", 
							 	     :override_bhrs=>"false", :escalation_enabled=>"1"}
							},
        }
        response.session[:flash][:notice].should eql "Unable to save SLA Policy"
        response.body.should =~ /New SLA Policy/
	end

	it "should edit a Sla Policy" do
		get :edit, :id => @sla_policy_1.id
		response.body.should =~ /"#{@sla_policy_1.name}"/
	end

	it "should update a Sla Policy" do
		ids = sla_detail_ids(@sla_policy_1)
		put :update, {
			:id =>  @sla_policy_1.id,
			:helpdesk_sla_policy =>{ :name =>"Updated - Sla Policy", 
			 	                      :id=> @sla_policy_1.id, 
			 	                      :description => @sla_policy_1.description,
			 	                      :datatype => {:ticket_type => "text"}, 
			 	                      :conditions =>{ :ticket_type =>["Feature Request"], :company_id =>""}, 
			 	                      :escalations =>{:response=>{"1"=>{:time =>"0", :agents_id =>["#{@agent_1.id}"]}}, 
			 	                                      :resolution=>{"1"=>{:time=>"0", :agents_id=>["#{@agent.id}"]},
			 	                                                    "2"=>{:time=>"1800", :agents_id=>["#{@agent_2.id}"]}
			 	                                                }
			 	                                    }
			 	                      },
	        :SlaDetails =>{ "0"=> { :name=>"SLA for urgent priority", :priority=>"4", :id=> ids[0], :response_time=>"900", :resolution_time=>"1800", 
			 	                     :override_bhrs=>"false", :escalation_enabled=>"1"},
                             "1"=> { :name=>"SLA for high priority", :priority=>"3", :id=> ids[1], :response_time=>"7200", :resolution_time=>"8400", 
                             	     :override_bhrs=>"false", :escalation_enabled=>"1"}, 
                             "2"=> { :name=>"SLA for medium priority", :priority=>"2", :id=> ids[2], :response_time=>"86400", :resolution_time=>"172800", 
                             	     :override_bhrs=>"false", :escalation_enabled=>"1"},
							 "3"=> { :name=>"SLA for low priority", :priority=>"1", :id=> ids[3], :response_time=>"2592000", :resolution_time=>"5184000", 
							 	     :override_bhrs=>"false", :escalation_enabled=>"1"}
							},
        }
        @sla_policy_1.reload
        response.session[:flash][:notice].should eql "The SLA Policy has been updated."
        @sla_policy_1.name.should eql "Updated - Sla Policy"
        @sla_policy_1.conditions[:ticket_type].should eql ["Feature Request"]
        @sla_policy_1.conditions[:company_id].should be_nil
        @sla_policy_1.escalations[:response]["1"][:agents_id].should eql [@agent_1.id]
        @sla_policy_1.escalations[:resolution]["2"][:agents_id].should eql [@agent_2.id]
        sla_details = Helpdesk::SlaDetail.find_by_id(ids[1])
        sla_details.resolution_time.should eql(8400)
	end

	it "should not update a Sla Policy" do
		ids = sla_detail_ids(@sla_policy_1)
		put :update, {
			:id =>  @sla_policy_1.id,
			:helpdesk_sla_policy =>{ :name =>"Update Sla Policy without conditions", 
			 	                      :id=> @sla_policy_1.id, 
			 	                      :description => @sla_policy_1.description,
			 	                      :datatype => {:ticket_type => "text"}, 
			 	                      :conditions =>{:company_id =>""}, 
			 	                      :escalations =>{:response=>{"1"=>{:time =>"0", :agents_id =>["#{@agent.id}"]}}, 
			 	                                      :resolution=>{"1"=>{:time=>"0", :agents_id=>["#{@agent_2.id}"]},
			 	                                                    "2"=>{:time=>"1800", :agents_id=>["#{@agent.id}"]}
			 	                                                }
			 	                                    }
			 	                      },
	        :SlaDetails =>{ "0"=> { :name=>"SLA for urgent priority", :priority=>"4", :id=> ids[0], :response_time=>"900", :resolution_time=>"1800", 
			 	                     :override_bhrs=>"false", :escalation_enabled=>"1"},
                             "1"=> { :name=>"SLA for high priority", :priority=>"3", :id=> ids[1], :response_time=>"7200", :resolution_time=>"8400", 
                             	     :override_bhrs=>"false", :escalation_enabled=>"1"}, 
                             "2"=> { :name=>"SLA for medium priority", :priority=>"2", :id=> ids[2], :response_time=>"86400", :resolution_time=>"172800", 
                             	     :override_bhrs=>"false", :escalation_enabled=>"1"},
							 "3"=> { :name=>"SLA for low priority", :priority=>"1", :id=> ids[3], :response_time=>"2592000", :resolution_time=>"5184000", 
							 	     :override_bhrs=>"false", :escalation_enabled=>"1"}
							},
        }
        @sla_policy_1.reload
        @sla_policy_1.name.should_not eql "Update Sla Policy without conditions"
        @sla_policy_1.conditions[:ticket_type].should eql ["Feature Request"]
        @sla_policy_1.escalations[:response]["1"][:agents_id].should eql [@agent_1.id]
        @sla_policy_1.escalations[:resolution]["2"][:agents_id].should_not eql [@agent.id]
    end
    
    it "should deactivate a Sla Policy" do
    	put :activate, :helpdesk_sla_policy => {:active => "false"}, :id => @sla_policy_1.id
    	@sla_policy_1.reload
    	response.session[:flash][:notice].should eql "The SLA Policy has been deactivated."
    	@sla_policy_1.active.should be_false
    end

    it "should activate a Sla Policy" do
    	@sla_policy_1.reload
    	put :activate, :helpdesk_sla_policy => {:active => "true"}, :id => @sla_policy_1.id
    	@sla_policy_1.reload
    	response.session[:flash][:notice].should eql "The SLA Policy has been activated."
    	@sla_policy_1.active.should be_true
    end    

    it "should not deactivate the Default Sla Policy" do
    	default_sla_policy = Helpdesk::SlaPolicy.find_by_is_default(1)
    	put :activate, :helpdesk_sla_policy => {:active => "false"}, :id => default_sla_policy.id
    	default_sla_policy.reload
    	response.session[:flash][:notice].should eql "The SLA Policy could not be activated"
    	default_sla_policy.active.should_not be_false
    end

    it "should reorder the Sla_policies" do
    	sla_policy_3 = Helpdesk::SlaPolicy.find_by_name("Sla Policy - Test Spec")
    	default = Helpdesk::SlaPolicy.find_by_is_default(1)
    	reorder_list = {
    		"#{default.id}" => 1,
    		"#{@sla_policy_1.id}" => 4,
    		"#{@sla_policy_2.id}" => 2,
    		"#{sla_policy_3.id}" => 3
    	}.to_json
		put :reorder, :reorderlist => reorder_list
		sla_policy_3.reload
		sla_policy_3.position.should eql(3)
		@sla_policy_1.reload
		@sla_policy_1.position.should eql(4)
		@sla_policy_2.reload
		@sla_policy_2.position.should eql(2)
	end

    it "should delete a Sla Policy" do
		delete :destroy, :id => @sla_policy_2.id
		sla_policy = Helpdesk::SlaPolicy.find_by_id(@sla_policy_2.id)
		sla_policy.should be_nil
	end
end