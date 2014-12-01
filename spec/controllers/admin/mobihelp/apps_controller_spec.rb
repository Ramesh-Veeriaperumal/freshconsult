require 'spec_helper'

describe Admin::Mobihelp::AppsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false


  before(:each) do
    login_admin
  end

  describe "should render index page" do
    before(:all) do
      @mobihelp_app = create_mobihelp_app
    end

    it "should list the mobihelp apps" do
      get :index
      response.body.should =~ /Mobihelp Apps/i
    end

    it "should show welcome page" do
      Mobihelp::App.delete_all
      get :index
      response.should render_template "admin/mobihelp/apps/index.html.erb"
      response.body.should =~ /Welcome to Mobihelp/i
    end
  end

  it "should create a new mobihelp app" do
    now = (Time.now.to_f*1000).to_i
    post  :create, {
      "mobihelp_app"=> {
        "name"=>"FreshApp #{now}", 
        "platform"=>"1", 
        "config"=> {
          "solutions"=>"2"
          }
        }
      }
    @account.mobihelp_apps.find_by_name("FreshApp #{now}").should be_an_instance_of(Mobihelp::App)
    @account.mobihelp_apps.find_by_name("FreshApp #{now}").platform.should be_eql(1)
  end

  it "should reject invalid mobihelp app and render new page " do
    get :new, :platform => 1
    post :create, :mobihelp_app => {:name => "", :platform => 1, :config => {"solutions"=>"2"}}
    response.should render_template('new')
  end

  it "should reject updatation with incorrect values and render edit page " do
    mobihelp_app = create_mobihelp_app
    get :edit, :id => mobihelp_app.id
    post :update, {
      "mobihelp_app"=>{
        "name"=> "", 
        "platform"=> mobihelp_app.platform, 
        "config"=>{
          "solutions"=> mobihelp_app.config[:solutions]
          }
        },
        "id" => mobihelp_app.id
      }
    response.should render_template('edit')
  end
  
  it "should go to new page" do 
    get :new, "platform" => 1
    response.should render_template "admin/mobihelp/apps/new.html.erb"
    response.body.should =~ /New Mobihelp App/
  end

  it "should go to edit page" do 
    mobihelp_app = create_mobihelp_app
    get :edit, "id" => mobihelp_app.id
    response.should render_template "admin/mobihelp/apps/edit.html.erb"
    response.body.should =~ /Edit Mobihelp App/
    response.body.should =~ /#{mobihelp_app.app_key}/
    response.body.should =~ /#{mobihelp_app.app_secret}/
  end

  it "should update the existing mobihelp app" do
    mobihelp_app = create_mobihelp_app
    now = (Time.now.to_f*1000).to_i
    post :update, {
      "mobihelp_app"=>{
        "name"=> "#{mobihelp_app.name} #{now}", 
        "platform"=> mobihelp_app.platform, 
        "config"=>{
          "solutions"=> mobihelp_app.config[:solutions]
          }
        },
        "id" => mobihelp_app.id
    }
    updated_mobihelp_app = @account.mobihelp_apps.find_by_id(mobihelp_app.id)
    updated_mobihelp_app.name.should be_eql("#{mobihelp_app.name} #{now}")
    updated_mobihelp_app.platform.should be_eql(mobihelp_app.platform)
  end

  it "should set deleted flag when a mobihelp_app is deleted" do
    mobihelp_app = create_mobihelp_app
    delete :destroy, :id => mobihelp_app.id
    Mobihelp::App.find_by_id(mobihelp_app.id).deleted.should be_true
  end

  it "should not delete a mobihelp_app" do
    id = Mobihelp::App.last.id + 1
    delete :destroy, :id => id
    Mobihelp::App.find_by_id(id).should be_nil
  end

end