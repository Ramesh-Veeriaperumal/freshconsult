require 'spec_helper'
load 'spec/support/account_helper.rb'

describe Admin::DataExportController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    Account.reset_current_account
    User.current = nil
    @account = create_new_account("dataexportspec", Faker::Internet.email)
    @agent = get_admin
  end

  before(:each) do
    @account.make_current
    login_admin
    
    @request.host = @account.full_domain
    @request.env['HTTP_REFERER'] = '/sessions/new'
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36
                                          (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"

    FileUtils.stubs(:remove_dir)

    Helpdesk::ExportDataWorker.any_instance.stubs(:export_forums_data)
    Helpdesk::ExportDataWorker.any_instance.stubs(:export_solutions_data)
    Helpdesk::ExportDataWorker.any_instance.stubs(:export_users_data)
    Helpdesk::ExportDataWorker.any_instance.stubs(:export_customers_data)
    Helpdesk::ExportDataWorker.any_instance.stubs(:export_tickets_data)
    Helpdesk::ExportDataWorker.any_instance.stubs(:export_groups_data)
    
    Resque.inline = true
  end

  after(:each) do
    Resque.inline = false
  end

  after(:all) do
    out_dir = "#{Rails.root}/tmp/#{@account.id}" 
    FileUtils.remove_dir(out_dir, true)
  end

  it 'should export users data' do
    Helpdesk::ExportDataWorker.any_instance.unstub(:export_users_data)
    post :export

    out_dir   = "#{Rails.root}/tmp/#{@account.id}" 
    exported_file = "#{out_dir}/Users.xml"
    expect { Pathname.new(exported_file).exist? }.to be_true

    users_xml = File.read(exported_file)
    users = Hash.from_trusted_xml users_xml
    admin = users["users"].find{|u| u["helpdesk_agent"] == true}
    admin.should_not be_blank
    admin["email"].should eql(@agent.email)
  end

  it 'should export forums data' do
    Helpdesk::ExportDataWorker.any_instance.unstub(:export_forums_data)
    post :export

    out_dir   = "#{Rails.root}/tmp/#{@account.id}" 
    exported_file = "#{out_dir}/Forums.xml"
    expect { Pathname.new(exported_file).exist? }.to be_true

    forums_xml = File.read(exported_file)
    forums = Hash.from_trusted_xml forums_xml
    forums["forum_categories"].should_not be_blank
    forums["forum_categories"].first["description"].should match("Default forum category")
    forums["forum_categories"].first["forums"].map{|f| f["name"]}.should eql(["Announcements", 
      "Feature Requests", "Tips and Tricks", "Report a problem"])
  end

  it 'should export solutions data' do
    Helpdesk::ExportDataWorker.any_instance.unstub(:export_solutions_data)
    post :export

    out_dir   = "#{Rails.root}/tmp/#{@account.id}" 
    exported_file = "#{out_dir}/Solutions.xml"
    expect { Pathname.new(exported_file).exist? }.to be_true

    solutions_xml = File.read(exported_file)
    solutions = Hash.from_trusted_xml solutions_xml
    solutions.should_not be_blank
    solutions["solution_categories"].should_not be_blank
    solutions["solution_categories"].map{|s| s["name"]}.should eql(["Default Category", "General"])
  end

  it 'should export customers data' do
    Helpdesk::ExportDataWorker.any_instance.unstub(:export_customers_data)
    customer_name = Faker::Name.name
    @account.customers.create(:name => customer_name)
    post :export

    out_dir   = "#{Rails.root}/tmp/#{@account.id}" 
    exported_file = "#{out_dir}/Customers.xml"
    expect { Pathname.new(exported_file).exist? }.to be_true

    customers_xml = File.read(exported_file)
    customers = Hash.from_trusted_xml customers_xml
    customers["customers"].should_not be_blank
    customers["customers"].first["name"].should eql(customer_name)
  end

  it 'should export tickets data' do
    Helpdesk::ExportDataWorker.any_instance.unstub(:export_tickets_data)
    post :export

    out_dir   = "#{Rails.root}/tmp/#{@account.id}" 
    exported_file = "#{out_dir}/Tickets0.xml"
    expect { Pathname.new(exported_file).exist? }.to be_true

    tickets_xml = File.read(exported_file)
    tickets = Hash.from_trusted_xml tickets_xml
    tickets.should_not be_blank
    tickets["helpdesk_tickets"].should_not be_blank
    tickets["helpdesk_tickets"].first["subject"].should eql("This is a sample ticket")
  end

  it 'should export groups data' do
    Helpdesk::ExportDataWorker.any_instance.unstub(:export_groups_data)
    post :export

    out_dir   = "#{Rails.root}/tmp/#{@account.id}" 
    exported_file = "#{out_dir}/Groups.xml"
    expect { Pathname.new(exported_file).exist? }.to be_true

    groups_xml = File.read(exported_file)
    groups = Hash.from_trusted_xml groups_xml
    groups.should_not be_blank
    groups["groups"].should_not be_blank
    groups["groups"].map{|g| g["name"]}.should eql(["Product Management", "QA", "Sales"])
  end

  it 'should download exported data' do
    Helpdesk::ExportDataWorker.any_instance.unstub(:export_groups_data)
    post :export

    @account.reload
    data_export = @account.data_exports.data_backup[0]
    get :download, { :source => data_export.source, :token => data_export.token }
    response.should redirect_to "helpdesk/attachments/#{data_export.attachment.id}"
  end

  it 'should not initiate export when other exports are in progress' do
    DataExport.any_instance.stubs(:completed?).returns(false)
    Helpdesk::ExportDataWorker.any_instance.unstub(:export_groups_data)
    post :export
    response.should redirect_to "account"
  end

  it 'should redirect to support home path if download url is not valid' do
    get :download, { :source => "Random source", :token => "random token" }
    response.should redirect_to "support/home"
  end
end