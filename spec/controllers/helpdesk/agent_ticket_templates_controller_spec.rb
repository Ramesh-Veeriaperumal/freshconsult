require 'spec_helper'

RSpec.describe Helpdesk::TicketTemplatesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account.ticket_templates.each {|tt| tt.destroy }
    @test_role = create_role({:name => "New role - unprivileged agent",
                              :privilege_list => ["manage_tickets", "edit_ticket_properties", "view_solutions", "manage_solutions",
                                                  "view_forums", "0", "0", "0", "0",
                                                  "", "0", "0", "0", "0"]} )
    @unpriv_agent = add_test_agent(@account,{:role => @test_role.id})
    @unpriv_agent.make_current
    @template_name = "Testing Ticket Template"
    create_sample_tkt_templates
    @templ_only_me_1 = create_personal_template(@unpriv_agent.id)
    @templ_only_me_2 = create_personal_template(@unpriv_agent.id)
  end

  before(:each) do
    log_in(@unpriv_agent)
  end

  after(:all) do
    @groups.destroy_all
  end

  it "should display the tickets template index page" do
    get :index
    response.should render_template "helpdesk/ticket_templates/index"
    response.body.should =~ /Ticket Templates/
    response.body.should =~ /Personal/
  end

  it "should display the tickets template personal index page" do
    get :index, :current_tab => "Shared"
    response.should redirect_to("/support/login")
  end

  it "should display the tickets template personal index page" do
    get :index, :current_tab => "sample"
    response.should redirect_to("/support/login")
  end

  it "should render new ticket template form" do
    get :new
    response.body.should =~ /New Template/
    response.should be_success
  end

  it "should create a new template" do
    id = @account.id
    post :create, {:helpdesk_ticket_template => {:name=>@template_name, :description=>Faker::Lorem.sentence(2), 
                                                :accessible_attributes => {:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]}},
                  :template_data => {:custom_field => {:"serial_number_#{id}" => "123", :"branch_#{id}" => Faker::Lorem.sentence(1),
                                                       :"additional_info_#{id}" => Faker::Lorem.paragraph, 
                                                       :"date_#{id}" => "28 Mar, 2016",:"average_#{id}" => "34.56", 
                                                       :"availability_#{id}" => "1" },
                                    :subject =>"sub from template", :status=>"2", :ticket_type=>"Lead", :group_id=>"4", 
                                    :responder_id=>"735", :priority=>"1", :tags => "jeju",
                                    :ticket_body_attributes=>{:description_html=>Faker::Lorem.paragraph},
                                    :attachments => [{:resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png')},
                                                     {:resource => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)}]
                                    }
                  }
    flash[:notice].should =~ /The template has been created./
    template = @account.ticket_templates.find_by_name(@template_name)
    template.should_not be_nil
    template[:template_data][:subject].should eql "sub from template"
    template[:template_data][:"average_#{id}"].should eql "34.56"
    template.accessible.should_not be_nil
    template.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
    template.accessible.user_accesses.should_not be_empty
    template.attachments.first.attachable_type.should be_eql("Helpdesk::TicketTemplate")
    template.attachments.size.should be_eql(2)
  end

  # NO title uniqueness in personal view.
  # if template is created with accessible "all_agents", for unpriv agent accessible will be set as "only_me" while creations.
  it "should create a new template with accessible as all_agents" do
    template_name = "Templates 1"
    post :create, {:helpdesk_ticket_template => {:name=>template_name, :description=>Faker::Lorem.sentence(2), 
                                                :accessible_attributes => {:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all_agents]}},
                  :template_data => {:subject =>"new issue in recharge", :status=>"3", :ticket_type=>"Feature Request" }}
    flash[:notice].should =~ /The template has been created./
    template = @account.ticket_templates.find_by_name(template_name)
    template.should_not be_nil
    template[:template_data][:subject].should eql "new issue in recharge"
    template.accessible.should_not be_nil
    template.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
    template.accessible.user_accesses.should_not be_empty
  end

  it "should render the template edit page" do
    get :edit, :id => @templ_only_me_1.id
    response.body.should =~ /#{@templ_only_me_1.name}/
    response.body.should =~ /Edit Template/
    response.should be_success
  end

  it "should update the template(only_me)" do
    id = @account.id
    @templ_only_me_1.name.should eql "Template - Only Me"
    @templ_only_me_1.attachments.size.should be_eql(0)
    @templ_only_me_1[:template_data][:ticket_type].should be_eql "Lead"
    @templ_only_me_1[:template_data][:subject].should be_eql "sample tkt"
    template_name = "#{@templ_only_me_1.name} updated"
    put :update, {:helpdesk_ticket_template => {:name=> template_name, :description=>@templ_only_me_1.name, 
                                                :accessible_attributes => {:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],
                                                  :id => @templ_only_me_1.accessible.id}},
                  :template_data => {:custom_field => {:"serial_number_#{id}" => "201", :"branch_#{id}" => Faker::Lorem.sentence(1),
                                                       :"additional_info_#{id}" => Faker::Lorem.paragraph, 
                                                       :"date_#{id}" => "28 Apr, 2015",:"average_#{id}" => "378.56", 
                                                       :"availability_#{id}" => "1" },
                                    :subject => "subject from template", :status=>@templ_only_me_1.template_data[:status], 
                                    :ticket_type=>"Question", :group_id=>"4", 
                                    :responder_id=>"735", :priority=>"1", :tags => "new_tkt",
                                    :ticket_body_attributes=>{:description_html=>Faker::Lorem.paragraph},
                                    :attachments => [{:resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png')}]
                                    },
                  :id => @templ_only_me_1.id }
    flash[:notice].should =~ /The template has been updated./
    template = @account.ticket_templates.find_by_id(@templ_only_me_1.id)
    template.should_not be_nil
    template.name.should eql template_name
    template[:template_data][:"serial_number_#{id}"].should eql "201"
    template[:template_data][:"average_#{id}"].should eql "378.56"
    template.accessible.should_not be_nil
    template.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
    template.attachments.first.attachable_type.should be_eql("Helpdesk::TicketTemplate")
    template.attachments.size.should be_eql(1)
  end

  # an unprivileged user can only edit/update/delete templates that are created by him
  it "should not update templates(all_agents & groups) that are not accessible to the unprivileged user" do
    template_name = "Trying to update grps to only_me"
    put :update, {:helpdesk_ticket_template => {:name=> template_name, :description=>@grps_template.name, 
                                                :accessible_attributes => {:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],
                                                  :id => @grps_template.accessible.id}},
                  :template_data => {:subject => "subject from template 1", :status=>@grps_template.template_data[:status], 
                                    :ticket_type=>"Question", :group_id=>"1", 
                                    :responder_id=>"735", :priority=>"1",
                                    :ticket_body_attributes=>{:description_html=>Faker::Lorem.paragraph},
                                    },
                  :id => @grps_template.id }
    response.should redirect_to("/support/login")
  end

  it "should not update templates to (all_agents & groups) if current user is unprivileged" do
    template_name = "Trying to update only_me to grps"
    put :update, {:helpdesk_ticket_template => {:name=> template_name, :description=>@templ_only_me_2.name, 
                                                :accessible_attributes => {:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups],
                                                  :group_ids=>[@groups[2].id, @groups[1].id], :id => @templ_only_me_2.accessible.id}},
                  :template_data => {:subject => "subject from template 1 - grps", :status=>@templ_only_me_2.template_data[:status], 
                                    :ticket_type=>"Question", :group_id=>"1",
                                    :responder_id=>"735", :priority=>"1",
                                    :ticket_body_attributes=>{:description_html=>Faker::Lorem.paragraph},
                                    },
                  :id => @templ_only_me_2.id }
    flash[:notice].should =~ /The template has been updated./
    template = @account.ticket_templates.find_by_id(@templ_only_me_2.id)
    template[:template_data][:subject].should be_eql "subject from template 1 - grps"
    template.accessible.access_type.should_not eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
    template.accessible.group_accesses.should be_empty
    template.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
    template.accessible.user_accesses.should_not be_empty
  end

  it "should clone a template" do
    @templ_only_me_1.reload
    get :clone, :id => @templ_only_me_1.id
    response.should render_template "helpdesk/ticket_templates/clone"
    response.body.should =~ /Copy of #{@templ_only_me_1.name}/
  end

  it "should delete multiple templates" do
    ids = ["#{@templ_only_me_1.id}", "#{@templ_only_me_2.id}"]
    delete :delete_multiple, :ids=> ids
    ids.each do |id|
      @account.ticket_templates.find_by_id(id).should be_nil
    end
  end

  it "should not get deleted when user doesn't have access to the template" do
    unaccess_templ_id = @grps_template.id
    delete :delete_multiple, :ids=> ["#{unaccess_templ_id}"]
    flash[:notice].should =~ /Could not delete the following templates due to an error. Please try again after sometime./
    @account.ticket_templates.find_by_id(unaccess_templ_id).should_not be_nil
  end
end