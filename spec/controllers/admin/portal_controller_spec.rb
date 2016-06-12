require 'spec_helper'

describe Admin::PortalController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  before(:all) do
    @forum_category_1 = create_test_category
    @forum_category_2 = create_test_category
    @forum_ids = [@forum_category_1.id, @forum_category_2.id]


    @solution_category_1 = create_category
    @solution_category_2 = create_category
    @solution_ids = [@solution_category_1.id, @solution_category_2.id]

    @test_product = create_product({:email => "#{Faker::Internet.domain_word}@#{@account.full_domain}"})
    @test_product_1 = create_product({:email => "#{Faker::Internet.domain_word}@#{@account.full_domain}"
                                    })
    @test_product_2 = create_product({:email => "#{Faker::Internet.domain_word}@#{@account.full_domain}"
                                    })
    @product_wit_portal = create_product({:name => "New Product without Portal", 
                                      :email => "#{Faker::Internet.domain_word}@#{@account.full_domain}",
                                      :portal_url => "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"})
    @product_wit_portal_1 = create_product({:name => "New Product without Portal", 
                                      :email => "#{Faker::Internet.domain_word}@#{@account.full_domain}",
                                      :portal_url => "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"})
    @product_wit_portal_2 = create_product({:name => "New Product without Portal", 
                                      :email => "#{Faker::Internet.domain_word}@#{@account.full_domain}",
                                      :portal_url => "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"})
  end

  it "should display All the portals" do
    get :index
    response.body.should =~ /Portals/
    response.should render_template "admin/portal/index"
    response.should be_success
  end

  it "should display Main portal edit if no multiporduct feature" do
    @account.features.multi_product.destroy
    @account.reload
    get :index
    response.body.should =~ /Portals/
    response.should render_template "admin/portal/edit"
    response.should be_success
    @account.features.multi_product.create
  end

  it "should render customer portal settings" do
    get :settings

    response.should render_template "admin/portal/settings"
    response.should be_success
  end

  it "should render a new portal form for the product" do
    get :enable, { :product => @test_product.id }

    response.should render_template "admin/portal/enable"
    response.should be_success
  end

  it "should create a new portal for the product" do
    portal_url = "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"

    post :create, :portal => {
                              :name => "Test portal",
                              :portal_url => portal_url,
                              :language => "da",
                              :forum_category_ids => @forum_ids, 
                              :solution_category_ids => @solution_ids, 
                              :preferences => {
                                :logo_link => Faker::Internet.url, 
                                :contact_info => "9886876",
                                :header_color => "#323234",
                                :tab_color => "#787675", 
                                :bg_color => "#efefef"
                              }
                            },
                  :product => @test_product.id

    default_category = @test_product.account.solution_categories.find_by_is_default(true)
    solution_ids = @solution_ids | [default_category.id] if default_category.present?
    new_portal = @test_product.portal
    new_portal.should_not be_nil
    new_portal.portal_url.should eql portal_url
    new_portal.name.should eql "Test portal"
    new_portal.template.should_not be_nil
    new_portal.language.should eql "da"
    new_portal.portal_solution_categories.map(&:solution_category_id).sort.should eql solution_ids.sort
    new_portal.portal_forum_categories.map(&:forum_category_id).sort.should eql @forum_ids.sort
    session["flash"][:notice].should eql "Portal has been enabled for '#{@test_product.name}'"
    response.should redirect_to(admin_portal_index_path)
  end

  it "should create and redirect to template for customization" do
    portal_url = "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"

    post :create, :portal => portal_params({:portal_url => portal_url}),
                  :product => @test_product_2.id,
                  :customize_portal => true

    new_portal = @test_product_2.portal
    new_portal.should_not be_nil
    new_portal.portal_url.should eql portal_url
    new_portal.name.should eql ""
    new_portal.template.should_not be_nil
    session["flash"][:notice].should eql "Portal has been enabled for '#{@test_product_2.name}'"
    response.should redirect_to(admin_portal_template_path(@test_product_2.portal.id))
  end

  it "should not create a new portal for the product if portal url is not unique" do
    portal_url = @product_wit_portal.portal.portal_url

    post :create, :portal => portal_params.merge({:portal_url => portal_url}),
                  :product => @test_product_1.id

    @test_product_1.portal.should be_nil
    response.should render_template "admin/portal/enable"
    response.should be_success
  end

  it "should not create a new portal for the product is already portal enabled" do
    portal_url = "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"

    post :create, :portal => portal_params({:portal_url => portal_url}),
                  :product => @product_wit_portal.id

    @product_wit_portal.portal.should_not be_nil
    response.should redirect_to(edit_admin_portal_path(@product_wit_portal.portal.id))
  end

  it "should update portal for the product" do
    portal_url = "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"
    portal = @product_wit_portal_2.portal

    put :update, :id => portal.id,
                :portal => portal_params({
                  :portal_url => portal_url,
                  :bg_color => '#000000'
                })
    portal.reload
    portal.should_not be_nil
    portal.portal_url.should eql portal_url
    session["flash"][:notice].should eql "Portal has been updated"
    response.should redirect_to(admin_portal_index_path)
  end

  it "should not update portal for the product if portal url is not unique" do
    portal_url = @product_wit_portal_1.portal.portal_url

    put :update, :id => @product_wit_portal_2.id,
                  :portal => portal_params({
                    :portal_url => portal_url,
                    :language => 'da',
                    :bg_color => '#000000'
                  })
    portal = @product_wit_portal_2.portal
    portal.should_not be_nil
    portal.portal_url.should_not eql portal_url
    portal.language.should eql 'en'
    response.body.should =~ /Portal url has already been taken/
  end

  it "should delete the portal for the product" do
    portal = @product_wit_portal_1.portal

    delete :destroy, :id => portal.id

    @product_wit_portal_1.reload
    @product_wit_portal_1.portal.should be_nil
    session["flash"][:notice].should eql "Portal of '#{@product_wit_portal_1.name}' has been disabled"
    response.should redirect_to(admin_portal_index_path)
  end

  it "should not delete the Main portal" do
    portal = @account.main_portal

    delete :destroy, :id => portal.id

    @account.reload
    @account.main_portal.should_not be_nil
    session["flash"][:notice].should eql "Main portal can not be disabled"
    response.should redirect_to(admin_portal_index_path)
  end

  it "should delete_logo of the product" do
    delete :delete_logo, :id => @product_wit_portal_2.portal.id
    logo = @account.attachments.first(:conditions=>["attachable_id = ? and attachable_type = ? and description = ?", 
                                                           "#{@product_wit_portal_2.portal.id}", "Portal", "logo"])
    logo.should be_nil
  end

  it "should delete_favicon of the product" do
    delete :delete_favicon, :id => @product_wit_portal_2.portal.id
    fav_icon = @account.attachments.first(:conditions=>["attachable_id = ? and attachable_type = ? and description = ?", 
                                                           "#{@product_wit_portal_2.portal.id}", "Portal", "fav_icon"])
    fav_icon.should be_nil
  end

  it "should update customer portal settings" do
    @account.sso_enabled = false
    @account.save(:validate =>false)
    agent_ids = []
    3.times do
      agent_ids << add_test_agent(@account).id
    end

    put :update_settings, { 
      :id => @account.id,
      :account => { 
        :features => {
          :anonymous_tickets => "0", 
          :open_solutions    => "1", 
          :auto_suggest_solutions => "0", 
          :open_forums=>"1",
          :google_signin=>"1", 
          :facebook_signin=>"0", 
          :twitter_signin=>"0", 
          :signup_link=>"1", 
          :captcha=>"1",
          :hide_portal_forums=>"0",
          :moderate_all_posts=>"1",
          :moderate_posts_with_links=>"0",
          :forum_captcha_disable =>"1"
        }
      },
      :forum_moderators => agent_ids
    }
    @account.reload
    available_feature = ["OpenSolutionsFeature","OpenForumsFeature","GoogleSigninFeature","SignupLinkFeature","CaptchaFeature",
                        "ModerateAllPostsFeature","ForumCaptchaDisableFeature"]
    available_feature.each do |feature|
      @account.features.find_by_type("#{feature}").should_not be_nil
    end

    restricted_feature = ["AnonymousTicketsFeature","AutoSuggestSolutionsFeature","FacebookSigninFeature","TwitterSigninFeature",
                          "HidePortalForumsFeature"]
    restricted_feature.each do |feature|
      @account.features.find_by_type("#{feature}").should be_nil
    end
    @account.forum_moderators.map(&:moderator_id).should =~ agent_ids
  end
end