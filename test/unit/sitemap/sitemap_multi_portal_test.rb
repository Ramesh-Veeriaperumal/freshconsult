require 'test_helper'
require "#{Rails.root}/spec/support/forum_helper.rb"
require "#{Rails.root}/spec/support/solution_builder_helper.rb"

class SitemapMultiPortalTest < ActiveSupport::TestCase
  include ForumHelper
  include SolutionBuilderHelper

  def setup
    @account = Account.first.make_current
    @main_portal = @account.main_portal.make_current
    @customer = create_dummy_customer
    @portal = create_product({:name => "New Portal",
      :email => "#{Faker::Internet.domain_word}@#{@account.full_domain}",
      :portal_url => "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"}).portal
  end

  def create_dummy_customer
    @customer = @account.all_users.where(:helpdesk_agent => true, :active => true, :deleted => false).where("email is not NULL").first
    if @customer.nil?
      @customer = FactoryGirl.build(:user, :account => @account, :email => Faker::Internet.email, :user_role => 3)
      @customer.save
    end
    @customer.make_current
    @customer
  end

  def create_product(option={})
    defaults = {:email => "#{Faker::Internet.domain_word}#{rand(0..9999)}@#{@account.full_domain}",:portal_name => Faker::Company.name}
    option = option.merge(defaults) { |key, v1, v2| v1 }

    test_product = FactoryGirl.build(:product, :name => option[:name] || Faker::Name.name, :description => Faker::Lorem.paragraph, :account_id => @account.id)
    test_product.save(validate: false)

    test_email_config = FactoryGirl.build(:email_config, :to_email => option[:email], :reply_email => option[:email],
      :primary_role =>"true", :name => test_product.name, :product_id => test_product.id,:account_id => @account.id,:active=>"true")
    test_email_config.save(validate: false)

    if option[:portal_url]
      test_portal = FactoryGirl.build(:portal, 
        :name=> option[:portal_name] || Faker::Name.name, 
        :portal_url => option[:portal_url], 
        :language=>"en",
        :product_id => test_product.id, 
        :forum_category_ids => (option[:forum_category_ids] || [""]),
        :solution_category_metum_ids => [""],
        :account_id => @account.id, 
        :preferences=>{ 
          :logo_link=>"", 
          :contact_info=>"", 
          :header_color=>"#252525",
          :tab_color=>"#006063", 
          :bg_color=>"#efefef" 
          })
      test_portal.save(validate: false)
    end
    test_product
  end

  def create_solution_categories(portal_ids)
    params = create_solution_category_alone(solution_default_params(:category))
    params[:solution_category_meta].merge!({:portal_ids => portal_ids})
    Solution::Builder.category(params)
  end

  def create_solution_folders(category_meta, visibility = 1)
    params = create_solution_folder_alone(solution_default_params(:folder).merge({
      :category_id => category_meta.id, :visibility => visibility }))
    Solution::Builder.folder(params)
  end

  def create_solution_articles(folder_meta, draft = 1)
    params = create_solution_article_alone(solution_default_params(:article, :title).merge({
      :folder_id => folder_meta.id, :user_id => @customer.id, :status => draft }))
    Solution::Builder.article(params)
  end

  def build_sitemap(portal)
    @xml = Nokogiri::XML.parse(Community::Sitemap.new(portal.reload).build)
  end

  test "Solution Category should not be present in incorrect portal" do
    category_meta = create_solution_categories([@main_portal.id])
    folder_meta = create_solution_folders(category_meta)
    
    build_sitemap(@portal)
    solution_category_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/solutions/#{category_meta.id}") }
    assert_empty solution_category_url, "solution category is present in wrong portal"
  end

  test "Solution Category should be present in correct portal" do
    category_meta = create_solution_categories([@main_portal.id])
    folder_meta = create_solution_folders(category_meta)
    
    build_sitemap(@main_portal)
    solution_category_url = @xml.css("loc").select { |node|
      node.text == ("#{@main_portal.url_protocol}://#{@main_portal.host}/support/solutions/#{category_meta.id}") }
    refute_empty solution_category_url, "solution category is not present in correct portal"
  end

  test "Solution Category should be present in both portals when available in both" do
    category_meta = create_solution_categories([@main_portal.id, @portal.id])
    folder_meta = create_solution_folders(category_meta)
    
    build_sitemap(@main_portal)
    main_portal_url = @xml.css("loc").select { |node|
      node.text == ("#{@main_portal.url_protocol}://#{@main_portal.host}/support/solutions/#{category_meta.id}") }
    refute_empty main_portal_url, "solution category is not present in main portal"
    
    build_sitemap(@portal)
    portal_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/solutions/#{category_meta.id}") }
    refute_empty portal_url, "solution category is not present in secondary portal"
  end

  test "Solution Folder should not be present in incorrect portal" do
    category_meta = create_solution_categories([@main_portal.id])
    folder_meta = create_solution_folders(category_meta)
    
    build_sitemap(@portal)
    solution_category_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/solutions/folders/#{folder_meta.id}") }
    assert_empty solution_category_url, "solution folder is present in wrong portal"
  end

  test "Solution Folder should be present in correct portal" do
    category_meta = create_solution_categories([@main_portal.id])
    folder_meta = create_solution_folders(category_meta)
    
    build_sitemap(@main_portal)
    solution_category_url = @xml.css("loc").select { |node|
      node.text == ("#{@main_portal.url_protocol}://#{@main_portal.host}/support/solutions/folders/#{folder_meta.id}") }
    refute_empty solution_category_url, "solution folder is not present in correct portal"
  end

  test "Solution Folder should be present in both portals when available in both" do
    category_meta = create_solution_categories([@main_portal.id, @portal.id])
    folder_meta = create_solution_folders(category_meta)
    
    build_sitemap(@main_portal)
    main_portal_url = @xml.css("loc").select { |node|
      node.text == ("#{@main_portal.url_protocol}://#{@main_portal.host}/support/solutions/folders/#{folder_meta.id}") }
    refute_empty main_portal_url, "solution folder is not present in main portal"
    
    build_sitemap(@portal)
    portal_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/solutions/folders/#{folder_meta.id}") }
    refute_empty portal_url, "solution folder is not present in secondary portal"
  end

  test "Published Solution Article should not be present in incorrect portal" do
    category_meta = create_solution_categories([@main_portal.id])
    folder_meta = create_solution_folders(category_meta)
    article_meta = create_solution_articles(folder_meta, 2)
    
    build_sitemap(@portal)
    solution_category_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/solutions/articles/#{article_meta.to_param}") }
    assert_empty solution_category_url, "solution article is present in wrong portal"
  end

  test "Published Solution Article should be present in correct portal" do
    category_meta = create_solution_categories([@main_portal.id])
    folder_meta = create_solution_folders(category_meta)
    article_meta = create_solution_articles(folder_meta, 2)
    
    build_sitemap(@main_portal)
    solution_category_url = @xml.css("loc").select { |node|
      node.text == ("#{@main_portal.url_protocol}://#{@main_portal.host}/support/solutions/articles/#{article_meta.to_param}") }
    refute_empty solution_category_url, "solution article is not present in correct portal"
  end

  test "Published Solution Article should be present in both portals when available in both" do
    category_meta = create_solution_categories([@main_portal.id, @portal.id])
    folder_meta = create_solution_folders(category_meta)
    article_meta = create_solution_articles(folder_meta, 2)
    
    build_sitemap(@main_portal)
    main_portal_url = @xml.css("loc").select { |node|
      node.text == ("#{@main_portal.url_protocol}://#{@main_portal.host}/support/solutions/articles/#{article_meta.to_param}") }
    refute_empty main_portal_url, "solution article is not present in main portal"
    
    build_sitemap(@portal)
    portal_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/solutions/articles/#{article_meta.to_param}") }
    refute_empty portal_url, "solution article is not present in secondary portal"
  end

  test "Discussion category should be present in correct portal" do
    category = create_test_category
    create_test_forum(category)
    build_sitemap(@main_portal)

    forum_category_url = @xml.css("loc").select { |node|
      node.text == ("#{@main_portal.url_protocol}://#{@main_portal.host}/support/discussions/#{category.id}") }
    refute_empty forum_category_url, "Discussion category is not present in correct portal"
  end

  test "Discussion category should not be present in incorrect portal" do
    category = create_test_category
    create_test_forum(category)
    build_sitemap(@main_portal)

    forum_category_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/discussions/#{category.id}") }
    assert_empty forum_category_url, "Discussion category is present in incorrect portal"
  end

  test "Discussion category should be present in both portals when available in both" do
    category = create_test_category_with_portals(@main_portal.id, @portal.id)
    create_test_forum(category)
    build_sitemap(@main_portal)

    forum_category_url = @xml.css("loc").select { |node|
      node.text == ("#{@main_portal.url_protocol}://#{@main_portal.host}/support/discussions/#{category.id}") }
    refute_empty forum_category_url, "Discussion category is not present in correct portal"

    build_sitemap(@portal)
    forum_category_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/discussions/#{category.id}") }
    refute_empty forum_category_url, "Discussion category is present in incorrect portal"
  end

  test "Discussion forum should be present in correct portal" do
    category = create_test_category
    forum = create_test_forum(category)
    build_sitemap(@main_portal)

    forum_url = @xml.css("loc").select { |node|
      node.text == ("#{@main_portal.url_protocol}://#{@main_portal.host}/support/discussions/forums/#{forum.id}") }
    refute_empty forum_url, "Discussion forum is not present in correct portal"
  end

  test "Discussion forum should not be present in incorrect portal" do
    category = create_test_category
    forum = create_test_forum(category)
    build_sitemap(@main_portal)

    forum_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/discussions/forums/#{forum.id}") }
    assert_empty forum_url, "Discussion forum is present in incorrect portal"
  end

  test "Discussion forum should be present in both portals when available in both" do
    category = create_test_category_with_portals(@main_portal.id, @portal.id)
    forum = create_test_forum(category)
    build_sitemap(@main_portal)

    forum_url = @xml.css("loc").select { |node|
      node.text == ("#{@main_portal.url_protocol}://#{@main_portal.host}/support/discussions/forums/#{forum.id}") }
    refute_empty forum_url, "Discussion forum is not present in correct portal"

    build_sitemap(@portal)
    forum_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/discussions/forums/#{forum.id}") }
    refute_empty forum_url, "Discussion forum is present in incorrect portal"
  end

  test "Discussion topic should be present in correct portal" do
    category = create_test_category
    forum = create_test_forum(category)
    topic = create_test_topic(forum)
    build_sitemap(@main_portal)

    forum_url = @xml.css("loc").select { |node|
      node.text == ("#{@main_portal.url_protocol}://#{@main_portal.host}/support/discussions/topics/#{topic.id}") }
    refute_empty forum_url, "Discussion topic is not present in correct portal"
  end

  test "Discussion topic should not be present in incorrect portal" do
    category = create_test_category
    forum = create_test_forum(category)
    topic = create_test_topic(forum)
    build_sitemap(@main_portal)

    forum_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/discussions/topics/#{topic.id}") }
    assert_empty forum_url, "Discussion topic is present in incorrect portal"
  end

  test "Discussion topic should be present in both portals when available in both" do
    category = create_test_category_with_portals(@main_portal.id, @portal.id)
    forum = create_test_forum(category)
    topic = create_test_topic(forum)
    build_sitemap(@main_portal)

    forum_url = @xml.css("loc").select { |node|
      node.text == ("#{@main_portal.url_protocol}://#{@main_portal.host}/support/discussions/topics/#{topic.id}") }
    refute_empty forum_url, "Discussion topic is not present in correct portal"

    build_sitemap(@portal)
    forum_url = @xml.css("loc").select { |node|
      node.text == ("#{@portal.url_protocol}://#{@portal.host}/support/discussions/topics/#{topic.id}") }
    refute_empty forum_url, "Discussion topic is present in incorrect portal"
  end

end
