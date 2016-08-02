require 'spec_helper'

RSpec.describe Helpdesk::TicketTemplatesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account.ticket_templates.each {|tt| tt.destroy }
    @template_name = "Testing Ticket Template"
    create_sample_tkt_templates
  end

  before(:each) do
    login_admin
  end

  after(:all) do
    @groups.destroy_all
  end

  it "should display the tickets template index page" do
    get :index
    response.should render_template "helpdesk/ticket_templates/index"
    response.body.should =~ /Ticket Templates/
    response.body.should =~ /Shared/
  end

  it "should render new ticket template form" do
    get :new
    response.body.should =~ /New Template/
    response.should be_success
  end

  it "should create a new template" do
    id = @account.id
    post :create, {:helpdesk_ticket_template => {:name=>@template_name, :description=>Faker::Lorem.sentence(2), 
                                                :accessible_attributes => {:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]}},
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
    template.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
    template.attachments.first.attachable_type.should be_eql("Helpdesk::TicketTemplate")
    template.attachments.size.should be_eql(2)
  end

  it "should create a new template with multiple groups" do
    templ_name = Faker::Name.name
    post :create, {:helpdesk_ticket_template => {:name=> templ_name, :description=>Faker::Lorem.sentence(2), 
                                                :accessible_attributes => {:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups],:group_ids=>[@groups[0].id, @groups[1].id]}},
                  :template_data => {:custom_field => {},
                                    :subject =>"payment not received", :status=>"2", :ticket_type=>"", :group_id=>"", 
                                    :responder_id=>"", :priority=>"1", :tags => "",
                                    :ticket_body_attributes=>{:description_html=>Faker::Lorem.paragraph},
                                    :attachments => [{:resource => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)}]
                                    }
                  }
    flash[:notice].should =~ /The template has been created./
    template = @account.ticket_templates.find_by_name(templ_name)
    template.should_not be_nil
    template[:template_data][:subject].should eql "payment not received"
    template[:template_data][:status].should eql "2"
    template.accessible.should_not be_nil
    template.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
    template.accessible.groups.map(&:id).sort == [@groups[0].id, @groups[1].id].sort
    template.attachments.first.attachable_type.should be_eql("Helpdesk::TicketTemplate")
    template.attachments.size.should be_eql(1)
  end

  #template access_type ALL_AGENTS AND GROUPS comes under SHARED VIEW
  #template access_type ONLY ME comes under PERSONAL VIEW
  #name duplications will be validated among the templates in the SHARED view.
  it "should not create a new template with existing name in same view" do 
    id = @account.id
    post :create, {:helpdesk_ticket_template => {:name=>@template_name, :description=>Faker::Lorem.sentence(2), 
                                                :accessible_attributes => {:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]}},
                  :template_data => {:custom_field => {},
                                    :subject =>"issue in the order", :status=>"2", :ticket_type=>"", :group_id=>"4", 
                                    :responder_id=>"", :priority=>"1", :tags => "",
                                    :ticket_body_attributes=>{:description_html=>Faker::Lorem.paragraph},
                                    :attachments => [{:resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png')}]
                                    }
                  }
    response.body.should =~ /Duplicate template. Title already exists/
  end

  it "should create a new template with existing name in different view" do 
    id = @account.id
    post :create, {:helpdesk_ticket_template => {:name=>@template_name, :description=>Faker::Lorem.sentence(2), 
                                                :accessible_attributes => {:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]}},
                  :template_data => {:custom_field => {},
                                    :subject =>"issue in the payment", :status=>"2", :ticket_type=>"", :group_id=>"4", 
                                    :responder_id=>"", :priority=>"1", :tags => "",
                                    :ticket_body_attributes=>{:description_html=>Faker::Lorem.paragraph},
                                    :attachments => [{:resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png')}]
                                    }
                  }
    flash[:notice].should =~ /The template has been created./
    template = @account.ticket_templates.only_me(User.current).find_by_name(@template_name)
    template.should_not be_nil
    template[:template_data][:subject].should eql "issue in the payment"
    template.accessible.should_not be_nil
    template.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
    template.accessible.users.should_not be_nil
    template.accessible.users.first.id == User.current.id
  end

  it "should render the template edit page" do
    get :edit, :id => @all_agents_template.id
    response.body.should =~ /#{@all_agents_template.name}/
    response.body.should =~ /Edit Template/
    response.should be_success
  end

  it "should update the template(all_agents to groups)" do
    id = @account.id
    @all_agents_template.name.should eql "Template - All agents"
    @all_agents_template.attachments.size.should be_eql(0)
    @all_agents_template[:template_data][:"average_#{id}"].should be_nil
    @all_agents_template[:template_data][:"serial_number_#{id}"].should be_nil
    @all_agents_template.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
    template_name = "#{@all_agents_template.name} updated as groups"
    put :update, {:helpdesk_ticket_template => {:name=> template_name, :description=>@all_agents_template.name, 
                                                :accessible_attributes => {:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups],
                                                  :group_ids=>[@groups[2].id, @groups[1].id], :id => @all_agents_template.accessible.id}},
                  :template_data => {:custom_field => {:"serial_number_#{id}" => "201", :"branch_#{id}" => Faker::Lorem.sentence(1),
                                                       :"additional_info_#{id}" => Faker::Lorem.paragraph, 
                                                       :"date_#{id}" => "28 Apr, 2015",:"average_#{id}" => "378.56", 
                                                       :"availability_#{id}" => "1" },
                                    :subject =>@all_agents_template.template_data[:subject], :status=>@all_agents_template.template_data[:status], 
                                    :ticket_type=>"Question", :group_id=>"4", 
                                    :responder_id=>"735", :priority=>"1", :tags => "new_tkt",
                                    :ticket_body_attributes=>{:description_html=>Faker::Lorem.paragraph},
                                    :attachments => [{:resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png')}]
                                    },
                  :id => @all_agents_template.id }
    flash[:notice].should =~ /The template has been updated./
    template = @account.ticket_templates.find_by_id(@all_agents_template.id)
    template.should_not be_nil
    template.name.should eql template_name
    template[:template_data][:"serial_number_#{id}"].should eql "201"
    template[:template_data][:"average_#{id}"].should eql "378.56"
    template.accessible.should_not be_nil
    template.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
    template.accessible.groups.map(&:id).sort == [@groups[1].id, @groups[2].id].sort
    template.attachments.first.attachable_type.should be_eql("Helpdesk::TicketTemplate")
    template.attachments.size.should be_eql(1)
  end

  it "should not update template with existing name in same view" do
    id = @account.id
    @all_agents_template.reload
    @all_agents_template.name.should eql "Template - All agents updated as groups"
    @all_agents_template[:template_data][:"serial_number_#{id}"].should eql "201"
    @all_agents_template.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
    template_name = @grps_template.name
    put :update, {:helpdesk_ticket_template => {:name=> template_name, :description=>@all_agents_template.name, 
                                                :accessible_attributes => {:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups],
                                                  :group_ids=>[@groups[2].id, @groups[1].id]}},
                  :template_data => {:custom_field => {:"serial_number_#{id}" => "52", :"branch_#{id}" => Faker::Lorem.sentence(1),
                                                       :"additional_info_#{id}" => Faker::Lorem.paragraph, 
                                                       :"date_#{id}" => "28 Apr, 2015",:"average_#{id}" => "100", 
                                                       :"availability_#{id}" => "1" },
                                    :subject =>@all_agents_template.template_data[:subject], :status=>@all_agents_template.template_data[:status], 
                                    :ticket_type=>"Question", :group_id=>"4", 
                                    :responder_id=>"735", :priority=>"1", :tags => "new_tkt",
                                    :ticket_body_attributes=>{:description_html=>Faker::Lorem.paragraph},
                                    :attachments => [{:resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png')}]
                                    },
                  :id => @all_agents_template.id }
    response.body.should =~ /Duplicate template. Title already exists/
    template = @account.ticket_templates.find_by_id(@all_agents_template.id)
    template.should_not be_nil
    template.name.should_not eql template_name
    template[:template_data][:"serial_number_#{id}"].should_not eql "52"
    template[:template_data][:"average_#{id}"].should_not eql "100"
    template.accessible.should_not be_nil
    template.accessible.access_type.should_not eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
  end

  it "should update the template(groups to only_me)" do
    id = @account.id
    @grps_template.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
    template_name = "#{@grps_template.name} updated to only_me"
    put :update, {:helpdesk_ticket_template => {:name=> template_name, :description=>@grps_template.name, 
                                                :accessible_attributes => {:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],
                                                  :id => @grps_template.accessible.id}},
                  :template_data => { :subject =>@grps_template.template_data[:subject], :status=>@grps_template.template_data[:status], 
                                      :ticket_type=>"Question", :group_id=>"1", 
                                      :responder_id=>"23", :priority=>"2", :tags => "new_tkt_1",
                                      :ticket_body_attributes=>{:description_html=>Faker::Lorem.paragraph}
                                    },
                  :id => @grps_template.id }
    flash[:notice].should =~ /The template has been updated./
    template = @account.ticket_templates.find_by_id(@grps_template.id)
    template.should_not be_nil
    template.name.should eql template_name
    template[:template_data][:"responder_id"].should eql "23"
    template.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
    template.accessible.group_accesses.should be_empty
    template.accessible.user_accesses.should_not be_empty
  end

  it "should update the template(only_me to all_agents)" do
    id = @account.id
    @user_template.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
    template_name = "#{@user_template.name} updated to all_agents"
    put :update, {:helpdesk_ticket_template => {:name=> template_name, :description=>@user_template.name, 
                                                :accessible_attributes => {:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all],
                                                  :id => @user_template.accessible.id}},
                  :template_data => { :subject =>@user_template.template_data[:subject], :status=>@user_template.template_data[:status], 
                                      :ticket_type=>"Question", :group_id=>"1", 
                                      :responder_id=>"23", :priority=>"3", :tags => "new_tk",
                                      :ticket_body_attributes=>{:description_html=>Faker::Lorem.paragraph}
                                    },
                  :id => @user_template.id }
    flash[:notice].should =~ /The template has been updated./
    template = @account.ticket_templates.find_by_id(@user_template.id)
    template.should_not be_nil
    template.name.should eql template_name
    template[:template_data][:"priority"].should eql "3"
    template.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
    template.accessible.user_accesses.should be_empty
  end

  it "should clone a template" do
    @all_agents_template.reload
    get :clone, :id => @all_agents_template.id
    response.should render_template "helpdesk/ticket_templates/clone"
    response.body.should =~ /Copy of #{@all_agents_template.name}/
  end

  it "should delete multiple templates" do
    ids = ["#{@all_agents_template.id}", "#{@user_template.id}", "#{@grps_template.id}"]
    delete :delete_multiple, :ids=> ids
    ids.each do |id|
      @account.ticket_templates.find_by_id(id).should be_nil
    end
  end
end