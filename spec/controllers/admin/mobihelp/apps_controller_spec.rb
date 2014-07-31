require 'spec_helper'

describe Admin::Mobihelp::AppsController do
  # integrate_views
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
      response.should render_template "admin/mobihelp/apps/index"
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
          "bread_crumbs"=>"10", 
          "debug_log_count"=>"50", 
          "solutions"=>"2", 
          "app_review_launch_count"=>"5"
          }
        }
      }
    RSpec.configuration.account.mobihelp_apps.find_by_name("FreshApp #{now}").should be_an_instance_of(Mobihelp::App)
    RSpec.configuration.account.mobihelp_apps.find_by_name("FreshApp #{now}").platform.should be_eql(1)
  end

  it "should reject invalid mobihelp app and render new page " do
    get :new, :platform => 1
    post :create, :mobihelp_app => {:name => "", :platform => 1, :config => {"bread_crumbs"=>"10", "debug_log_count"=>"50", 
          "solutions"=>"2", "app_review_launch_count"=>"5"}}
    response.should render_template('new',layout: :application)
  end

  it "should reject updatation with incorrect values and render edit page " do
    mobihelp_app = create_mobihelp_app
    get :edit, :id => mobihelp_app.id
    post :update, {
      "mobihelp_app"=>{
        "name"=> "", 
        "platform"=> mobihelp_app.platform, 
        "config"=>{
          "bread_crumbs"=> mobihelp_app.config[:bread_crumbs], 
          "debug_log_count"=> mobihelp_app.config[:debug_log_count], 
          "solutions"=> mobihelp_app.config[:solutions], 
          "app_review_launch_count"=> mobihelp_app.config[:app_review_launch_count]
          }
        },
        "id" => mobihelp_app.id
      }
    response.should render_template('edit',layout: :application)
  end
  
  it "should go to new page" do 
    get :new, "platform" => 1
    response.should render_template "admin/mobihelp/apps/new"
    response.body.should =~ /New Mobihelp App/
  end

  it "should go to edit page" do 
    mobihelp_app = create_mobihelp_app
    get :edit, "id" => mobihelp_app.id
    response.should render_template "admin/mobihelp/apps/edit"
    response.body.should =~ /Edit Mobihelp App/
    response.body.should =~ /#{mobihelp_app.app_key}/
    response.body.should =~ /#{mobihelp_app.app_secret}/
  end

  it "should update the existing mobihelp app" do
    mobihelp_app = create_mobihelp_app
    post :update, {
      "mobihelp_app"=>{
        "name"=> mobihelp_app.name, 
        "platform"=> mobihelp_app.platform, 
        "config"=>{
          "bread_crumbs"=> mobihelp_app.config[:bread_crumbs], 
          "debug_log_count"=> mobihelp_app.config[:debug_log_count], 
          "solutions"=> mobihelp_app.config[:solutions], 
          "app_review_launch_count"=> "15"
          }
        },
        "id" => mobihelp_app.id
    }
    updated_mobihelp_app = RSpec.configuration.account.mobihelp_apps.find_by_id(mobihelp_app.id)
    updated_mobihelp_app.config[:app_review_launch_count].should be_eql("15")
    updated_mobihelp_app.platform.should be_eql(mobihelp_app.platform)
  end

  it "should delete a mobihelp_app" do
    mobihelp_app = create_mobihelp_app
    delete :destroy, :id => mobihelp_app.id
    Mobihelp::App.find_by_id(mobihelp_app.id).deleted.should be_truthy
  end

  it "should not delete a mobihelp_app" do
    id = Mobihelp::App.last.id + 1
    delete :destroy, :id => id
    Mobihelp::App.find_by_id(id).should be_nil
  end

end