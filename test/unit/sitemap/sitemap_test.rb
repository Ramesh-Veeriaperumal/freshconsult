require 'test_helper'
require "#{Rails.root}/spec/support/forum_helper.rb"
require "#{Rails.root}/spec/support/solution_builder_helper.rb"

class SitemapTest < ActiveSupport::TestCase
  include ForumHelper
  include SolutionBuilderHelper

  def setup
    @account = Account.first.make_current
    @portal = @account.portals.first.make_current
    @customer = create_dummy_customer
    if @account.features_included?(:enable_multilingual)
      @account.features.enable_multilingual.destroy
      @account.reload
    end
  end

  def create_dummy_customer
    @customer = @account.all_users.where(:helpdesk_agent => false, :active => true, :deleted => false).where("email is not NULL").first
    if @customer.nil?
      @customer = FactoryGirl.build(:user, :account => @account, :email => Faker::Internet.email, :user_role => 3)
      @customer.save
    end
    @customer.make_current
    @customer
  end

  def build_sitemap
    @xml = Nokogiri::XML.parse(Community::Sitemap.new(@portal).build)
  end

  def create_solution_category
    Solution::Builder.category(create_solution_category_alone(solution_default_params(:category)))
  end

  def create_solution_folder(category_meta, visibility = 1)
    Solution::Builder.folder(create_solution_folder_alone(solution_default_params(:folder).merge({
      :category_id => category_meta.id, :visibility => visibility})))
  end

  def create_solution_article(folder_meta, draft = 1)
    article_params = create_solution_article_alone(solution_default_params(:article, :title).merge({
      :folder_id => folder_meta.id, :user_id => @customer.id, :status => draft }))
    Solution::Builder.article(article_params)
  end

  # FORUMS
  test "No discussion URLs should be present in sitemap, when there are no forum categories" do
    @account.forum_categories.map { |c| c.destroy }
    build_sitemap
    forum_category_urls = @xml.css("loc").select { |node|
      node.text.include?("/support/discussions") }
    assert_empty forum_category_urls, "sitemap contains discussion urls when discussions are no present"
  end

  test "No discussion URLs should be present in sitemap, when there are discussion categories but no forums" do
    create_test_category
    @account.forums.map { |f| f.destroy }
    build_sitemap
    forum_urls = @xml.css("loc").select { |node|
      node.text.include?("/support/discussions") }
    assert_empty forum_urls, "sitemap contains discussion urls when discussions are no present"
  end

  test "discussion home URL is present, when there is category and forum present" do
    create_test_forum(create_test_category)
    build_sitemap
    forum_home_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/discussions") }
    refute_empty forum_home_url, "sitemap does not contain discussion home URL"
  end

  test "discussion category URL is present, when there is category and forum present" do
    category = create_test_category #forums aleady exists
    build_sitemap
    forum_category_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/discussions/#{category.id}") }
    refute_empty forum_category_url, "sitemap contains discussion category URL when forum is not present"
  end

  test "discussion URL is present, when there is category and forum present" do
    forum = create_test_forum(create_test_category)
    build_sitemap
    forum_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/discussions/forums/#{forum.id}") }
    refute_empty forum_url, "sitemap does not contain discussion URL"
  end

  test "topic URL is present" do
    topic = create_test_topic(create_test_forum(create_test_category))
    build_sitemap
    forum_topic_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/discussions/topics/#{topic.id}") }
    refute_empty forum_topic_url, "sitemap does not contain topic URL"
  end

  test "No discussion URLs should be present, When 'who can view forums' is set as none" do
    @account.enable_setting(:hide_portal_forums) unless @account.hide_portal_forums_enabled?
    create_test_topic(create_test_forum(create_test_category))
    build_sitemap
    forum_category_urls = @xml.css("loc").select { |node|
      node.text.include?("/support/discussions") }
    assert_empty forum_category_urls, "sitemap contains discussion urls when discussions cannot be viewed by anyone"
  end

  # SOLUIONS
  test "No solution URLs should be present in sitemap, when there are no solution categories" do
    @account.solution_category_meta.map { |c| c.destroy unless c.is_default? }
    build_sitemap
    solution_urls = @xml.css("loc").select { |node|
      node.text.include?("/support/solutions") }
    assert_empty solution_urls, "sitemap contains solution urls when solutions are no present"
  end

  test "No solution URLs should be present in sitemap, when there are solution categories but no solution folders" do
    create_solution_category
    @account.solution_folder_meta.map { |f| f.destroy unless f.is_default? }
    build_sitemap
    solution_urls = @xml.css("loc").select { |node|
      node.text.include?("/support/solutions") }
    assert_empty solution_urls, "sitemap contains solution urls when solution folders are no present"
  end

  test "No solution URLs should be present when there are no public folders" do
    category_meta = create_solution_category
    @account.solution_folder_meta.map { |f| f.destroy unless f.is_default? }
    create_solution_folder(category_meta, 2) #logged_users
    create_solution_folder(category_meta, 3) #agents
    create_solution_folder(category_meta, 4) #company_users
    build_sitemap
    solution_urls = @xml.css("loc").select { |node|
      node.text.include?("/support/solutions") }
    assert_empty solution_urls, "sitemap contains solution urls when public folders are no present"
  end

  test "sitemap should not contain default solution category" do
    default_category = @account.solution_category_meta.where(:is_default => true).first
    build_sitemap
    default_category_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/solutions/#{default_category.id}") }
    assert_empty default_category_url, "sitemap contains default category"
  end

  test "sitemap should not contain draft folder" do
    default_folder = @account.solution_folder_meta.where(:is_default => true).first
    build_sitemap
    default_folder_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/solutions/folders/#{default_folder.id}") }
    assert_empty default_folder_url, "sitemap contains draft folder"
  end

  test "solution home url is present when category and folder is present" do
    create_solution_folder(create_solution_category)
    build_sitemap
    solution_home_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/solutions") }
    refute_empty solution_home_url, "solution home url is not present when category and folder is present"
  end

  test "solution category url is present when category and folder is present" do
    category_meta = create_solution_category
    create_solution_folder(category_meta)
    build_sitemap
    solution_category_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/solutions/#{category_meta.id}") }
    refute_empty solution_category_url, "solution category url not present when folder is present"
  end

  test "solution folder url is present" do
    folder_meta = create_solution_folder(create_solution_category)
    build_sitemap
    solution_folder_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/solutions/folders/#{folder_meta.id}") }
    refute_empty solution_folder_url, "solution folder url not present"
  end

  test "published solution article url is present" do
    article_meta = create_solution_article(create_solution_folder(create_solution_category), 2)
    build_sitemap
    solution_article_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/solutions/articles/#{article_meta.to_param}") }
    refute_empty solution_article_url, "published solution article url not present"
  end

  test "draft solution article url is not present" do
    article_meta = create_solution_article(create_solution_folder(create_solution_category))
    build_sitemap
    solution_article_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/solutions/articles/#{article_meta.to_param}") }
    assert_empty solution_article_url, "draft solution article url is present"
  end

end
