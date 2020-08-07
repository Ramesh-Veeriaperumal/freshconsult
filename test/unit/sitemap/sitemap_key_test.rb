require 'test_helper'
require "#{Rails.root}/spec/support/forum_helper.rb"
require "#{Rails.root}/spec/support/solution_builder_helper.rb"

class SitemapKeyTest < ActiveSupport::TestCase
  include ForumHelper
  include SolutionBuilderHelper
  include Redis::RedisKeys
  include Redis::PortalRedis

  def setup
    @account = Account.first.make_current
    @portal = @account.portals.first.make_current
    @portal.clear_sitemap_cache
    AwsWrapper::S3.delete(S3_CONFIG[:bucket], "sitemap/#{@account.id}/#{@portal.id}.xml")
    @customer = create_dummy_customer
    @key = SITEMAP_OUTDATED % { :account_id => @account.id }
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

  test "sitemap is not generated when redis key is not set for account" do
    remove_portal_redis_key(@key)
    worker = Community::GenerateSitemap.new
    worker.perform(@account.id)
    xml_text = @portal.fetch_sitemap
    assert_nil xml_text, "sitemap is generated when redis key is not set"
  end

  test "sitemap is not generated when sitemap feature is not set for account" do
    if @account.sitemap_enabled?
      @account.features.sitemap.destroy
      @account.reload
    end
    new_fc = create_test_category #to set redis key
    worker = Community::GenerateSitemap.new
    worker.perform(@account.id)
    xml_text = @portal.fetch_sitemap
    assert_nil xml_text, "sitemap is generated when sitemap feature is not enabled"
  end

  test "sitemap is generated only if sitemap feature is enabled and redis key is set for the account" do
    @account.add_features(:sitemap) unless @account.sitemap_enabled?
    new_fc = create_test_category
    worker = Community::GenerateSitemap.new
    worker.perform(@account.id)
    xml_text = @portal.fetch_sitemap
    refute_empty xml_text, "sitemap is not generated when sitemap feature is enabled and redis key is set"
  end

  # CREATION

  test "redis key is set when forum category is created" do
    remove_portal_redis_key(@key)
    create_test_category
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when forum category is created"
  end

  test "redis key is set when forum is created" do
    forum_category = create_test_category
    remove_portal_redis_key(@key)
    create_test_forum(forum_category)
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when forum is created"
  end

  test "redis key is set when topic is created" do
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    remove_portal_redis_key(@key)
    create_test_topic(forum)
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when topic is created"
  end

  test "redis key is set when post is created" do
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    topic = create_test_topic(forum)
    remove_portal_redis_key(@key)
    create_test_post(topic)
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when post is created"
  end

  test "redis key is set when solution category is created" do
    remove_portal_redis_key(@key)
    Solution::Builder.category(create_solution_category_alone(solution_default_params(:category)))
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when solution category is created"
  end

  test "redis key is set when solution folder is created" do
    category_meta = Solution::Builder.category(create_solution_category_alone(solution_default_params(:category)))
    remove_portal_redis_key(@key)
    folder_params = create_solution_folder_alone(solution_default_params(:folder).merge({:category_id => category_meta.id}))
    Solution::Builder.folder(folder_params)
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when solution folder is created"
  end

  test "redis key is set when solution article is created" do
    category_meta = Solution::Builder.category(create_solution_category_alone(solution_default_params(:category)))
    folder_params = create_solution_folder_alone(solution_default_params(:folder).merge({:category_id => category_meta.id}))
    folder_meta = Solution::Builder.folder(folder_params)
    remove_portal_redis_key(@key)
    article_params = create_solution_article_alone(solution_default_params(:article, :title).merge({
      :folder_id => folder_meta.id, :user_id => @customer.id }))
    Solution::Builder.article(article_params)
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when solution article is created"
  end

  # UPDATION

  test "redis key is set when forum category is updated" do
    
    category = create_test_category
    remove_portal_redis_key(@key)
    category.description = "Update" + category.description
    category.save
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when forum category is updated"
  end

  test "redis key is set when forum is updated" do
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    remove_portal_redis_key(@key)
    forum.description = "Test" + forum.description
    forum.save
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when forum is updated"
  end

  test "redis key is set when topic is updated" do
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    topic = create_test_topic(forum)
    remove_portal_redis_key(@key)
    topic.title = "Test" + topic.title
    topic.save
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when topic is updated"
  end

  test "redis key is set when post is updated" do
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    topic = create_test_topic(forum)
    post = create_test_post(topic)
    remove_portal_redis_key(@key)
    post.body = "Test" + post.body
    post.save
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when post is updated"
  end

  test "redis key is set when solution category is updated" do
    key = SITEMAP_OUTDATED % { :account_id => @account.id }
    category_meta = Solution::Builder.category(create_solution_category_alone(solution_default_params(:category)))
    remove_portal_redis_key(@key)
    category = category_meta.solution_categories.first
    category.description = "Test" + category.description
    category.save
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when solution category is updated"
  end

  test "redis key is set when solution folder is updated" do
    category_meta = Solution::Builder.category(create_solution_category_alone(solution_default_params(:category)))
    folder_params = create_solution_folder_alone(solution_default_params(:folder).merge({
      :category_id => category_meta.id, :visibility => 1}))
    folder_meta = Solution::Builder.folder(folder_params)
    remove_portal_redis_key(@key)
    folder = folder_meta.primary_folder
    folder.description = "Test" + folder.description
    folder.save
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when solution folder is updated"
  end

  test "redis key is set when solution article is updated" do
    category_meta = Solution::Builder.category(create_solution_category_alone(solution_default_params(:category)))
    folder_params = create_solution_folder_alone(solution_default_params(:folder).merge({:category_id => category_meta.id}))
    folder_meta = Solution::Builder.folder(folder_params)
    article_params = create_solution_article_alone(solution_default_params(:article, :title).merge({
      :folder_id => folder_meta.id, :user_id => @customer.id }))
    article_meta = Solution::Builder.article(article_params)
    remove_portal_redis_key(@key)
    article = article_meta.solution_articles.first
    article.description = "Test" + article.description
    article.save
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when solution article is updated"
  end

  # DELETION

  test "redis key is set when forum category is deleted" do
    category = create_test_category
    remove_portal_redis_key(@key)
    category.destroy
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when forum category is deleted"
  end

  test "redis key is set when forum is deleted" do
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    remove_portal_redis_key(@key)
    forum.destroy
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when forum is deleted"
  end

  test "redis key is set when topic is deleted" do
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    topic = create_test_topic(forum)
    remove_portal_redis_key(@key)
    topic.destroy
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when topic is deleted"
  end

  test "redis key is set when post is deleted" do
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    topic = create_test_topic(forum)
    post = create_test_post(topic)
    remove_portal_redis_key(@key)
    post.destroy
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when post is deleted"
  end

  test "redis key is set when solution category is deleted" do
    category_meta = Solution::Builder.category(create_solution_category_alone(solution_default_params(:category)))
    remove_portal_redis_key(@key)
    category_meta.destroy
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when solution category is deleted"
  end

  test "redis key is set when solution folder is deleted" do
    category_meta = Solution::Builder.category(create_solution_category_alone(solution_default_params(:category)))
    folder_params = create_solution_folder_alone(solution_default_params(:folder).merge({
      :category_id => category_meta.id}))
    folder_meta = Solution::Builder.folder(folder_params)
    remove_portal_redis_key(@key)
    folder_meta.destroy #Check : Need to find out why redis key does not get set in destroy
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when solution folder is deleted"
  end

  test "redis key is set when solution article is deleted" do
    category_meta = Solution::Builder.category(create_solution_category_alone(solution_default_params(:category)))
    folder_params = create_solution_folder_alone(solution_default_params(:folder).merge({:category_id => category_meta.id}))
    folder_meta = Solution::Builder.folder(folder_params)
    article_params = create_solution_article_alone(solution_default_params(:article, :title).merge({
      :folder_id => folder_meta.id, :user_id => @customer.id }))
    article_meta = Solution::Builder.article(article_params)
    remove_portal_redis_key(@key)
    article_meta.destroy
    assert_equal true, portal_redis_key_exists?(@key), "redis key is not set when solution article is deleted"
  end

  test "redis key should be cleared after sitemap is generated" do
    new_fc = create_test_category
    worker = Community::GenerateSitemap.new
    worker.perform(@account.id)
    refute_equal true, portal_redis_key_exists?(@key), "redis key is not cleared after sitemap is generated"
  end

  test "Valid domain with correct protocol and host name" do
    @sitemap = Community::Sitemap.new(@portal).build
    @xml = Nokogiri::XML.parse(@sitemap)
    invalid_domain = @xml.css("loc").select { |node| 
      node.text.exclude?("#{@portal.url_protocol}://#{@portal.host}") }
    assert_empty invalid_domain, 'sitemap domain is invalid'
  end

end
