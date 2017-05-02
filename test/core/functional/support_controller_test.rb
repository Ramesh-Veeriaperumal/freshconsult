require_relative '../test_helper'

class SupportControllerTest < ActionController::TestCase
  def setup
    super
    @account.add_features(:sitemap) unless @account.sitemap_enabled?
    @main_portal = @account.main_portal.make_current
  end

  #Robots Action: Begin
  test "robots file should be accessible in txt format only" do
    get :robots, {:format => "txt"}
    assert_response :success
    assert_equal "text/plain", response.content_type
  end

  test "robots file should not be accessible in any other format but txt" do
    get :robots, {:format => "xml"}
    assert_response 404
    refute_equal "text/plain", response.content_type
  end

  test "robots file should be accessible if logged in" do
    login_admin
    get :robots, {:format => "txt"}
    assert_response :success
  end

  test "robots file should be accessible if not logged in" do
    login_admin.destroy
    get :robots, {:format => "txt"}
    assert_response :success
  end

  test "robots file should be accessed from cache after first time" do
    get :robots, {:format => "txt"}
    key = Digest::SHA1.hexdigest("#{@main_portal.cache_prefix}/robots.txt")
    robots = SupportController.cache_store.fetch("views/#{key}.txt")
    assert_includes robots, "Sitemap:"
  end

  test "robots file should contain sitemap if acccount has sitemap feature enabled" do
    get :robots, {:format => "txt"}
    assert_response :success
    assert_includes response.body, "Sitemap:"
  end

  test "robots file should not contain sitemap if account does not have sitemap feature enabled" do
    if @account.sitemap_enabled?
      @account.features.sitemap.destroy
      @account.subscription.subscription_plan_id = 6 #new sprout plan
      @account.subscription.save 
      @account.reload
    end
    get :robots, {:format => "txt"}
    assert_response :success
    assert (not response.body.include? "Sitemap:")
  end

  test "routing for robots" do
    assert_routing '/robots', controller: "support", action: "robots", format: "text"
  end

  test "robots file should contain https for sitemap if account is SSL enabled" do
    unless @account.ssl_enabled?
      @account.ssl_enabled = true
      @account.save
    end
    get :robots, {:format => "txt"}
    assert_response :success
    assert_includes response.body, "Sitemap: https://"
  end

  test "robots file should contain http for sitemap if account is not SSL enabled" do
    if @account.ssl_enabled?
      @account.ssl_enabled = false
      @account.save
    end
    get :robots, {:format => "txt"}
    assert_response :success
    assert_includes response.body, "Sitemap: http://"
  end
  #Robots Action: End
end