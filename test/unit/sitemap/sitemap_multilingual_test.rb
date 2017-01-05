require 'test_helper'
require "#{Rails.root}/spec/support/forum_helper.rb"
require "#{Rails.root}/spec/support/solution_builder_helper.rb"

class SitemapMultilingualTest < ActiveSupport::TestCase
  include ForumHelper
  include SolutionBuilderHelper

  $account = Account.first.make_current
  $portal = $account.portals.first.make_current
  $lang_list_objs = Language.all.sample(3) - [$account.language_object]

  def setup
    @account = $account.make_current
    @portal = $portal.make_current
    @lang_list_codes = $lang_list_objs.map(&:code)
    @lang_list = $lang_list_objs.map(&:to_key)
    @customer = create_dummy_customer
    enable_multilingual
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

  def enable_multilingual
    @account.launch(:translate_solutions) unless @account.launched?(:translate_solutions)
    @account.add_features(:enable_multilingual) unless @account.features_included?(:enable_multilingual)
    @account.add_features(:multi_language) unless @account.features_included?(:multi_language)
    @account.account_additional_settings.supported_languages = @lang_list_codes
    @account.account_additional_settings.additional_settings[:portal_languages] = @lang_list_codes
    @account.save
    reload(@account)
  end

  def language_versions
    [@lang_list.first] + [:primary]
  end

  def build_sitemap
    @xml = Nokogiri::XML.parse(Community::Sitemap.new(@portal.reload).build)
  end

  def create_solution_categories
    Solution::Builder.category(create_solution_category_alone(solution_default_params(:category).merge({
      :lang_codes => language_versions }))).reload
  end

  def create_solution_folders(category_meta, visibility = 1)
    Solution::Builder.folder(create_solution_folder_alone(solution_default_params(:folder).merge({
      :category_id => category_meta.id, :visibility => visibility, :lang_codes => language_versions }))).reload
  end

  def create_solution_articles(folder_meta, draft = 1)
    Solution::Builder.article(create_solution_article_alone(solution_default_params(:article, :title).merge({
      :folder_id => folder_meta.id, :user_id => @customer.id, :lang_codes => language_versions, :status => draft }))).reload
  end

  def alternate(element, url)
    element.namespace.present? && element.namespace.prefix == "xhtml" && element.name == "link" && element["href"] == url
  end

  def reload(object)
    object.reload
    object.remove_instance_variable("@all_portal_language_objects") if object.instance_variables.include?("@all_portal_language_objects".to_sym)
    object.remove_instance_variable("@portal_languages_objects") if object.instance_variables.include?("@portal_languages_objects".to_sym)
    return object
  end

  test "sitemap contains primary solution category" do
    category_meta = create_solution_categories
    create_solution_folders(category_meta)
    build_sitemap
    primary_category_url = @xml.css("loc").select { |node| 
      node.text == "#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/#{category_meta.id}"
    }
    refute_empty primary_category_url, "sitemap does not contain primary solution category"
  end

  test "sitemap contains primary solution folder" do
    folder_meta = create_solution_folders(create_solution_categories)
    build_sitemap
    primary_folder_url = @xml.css("loc").select { |node| 
      node.text == "#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/folders/#{folder_meta.id}"
    }
    refute_empty primary_folder_url, "sitemap does not contain primary solution folder"
  end

  test "sitemap contains primary published article" do
    article_meta = create_solution_articles(create_solution_folders(create_solution_categories), 2)
    build_sitemap
    primary_article_url = @xml.css("loc").select { |node|  
      node.text == "#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/articles/#{article_meta.to_param}"
    }
    refute_empty primary_article_url, "sitemap does not contain primary published article"
  end

  test "sitemap does not contain primary draft article" do
    article_meta = create_solution_articles(create_solution_folders(create_solution_categories), 1)
    build_sitemap
    primary_article_url = @xml.css("loc").select { |node|  
      node.text == "#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/articles/#{article_meta.to_param}"
    }
    assert_empty primary_article_url, "sitemap contains primary draft article"
  end

  test "sitemap contains translated solution category" do
    category_meta = create_solution_categories
    create_solution_folders(category_meta)
    build_sitemap
    translation_url = @xml.css("loc").select { |node| 
      node.text == "#{@portal.url_protocol}://#{@portal.host}/#{@lang_list_codes.first}/support/solutions/#{category_meta.id}" 
    }
    refute_empty translation_url, "sitemap does not contain translated solution category"
  end

  test "sitemap contains translated solution folder" do
    folder_meta = create_solution_folders(create_solution_categories)
    build_sitemap
    translation_url = @xml.css("loc").select { |node|
      node.text == "#{@portal.url_protocol}://#{@portal.host}/#{@lang_list_codes.first}/support/solutions/folders/#{folder_meta.id}"
    }
    refute_empty translation_url, "sitemap does not contain translated solution folder"
  end

  test "sitemap contains translated published solution article" do
    article_meta = create_solution_articles(create_solution_folders(create_solution_categories), 2)
    translated_article = article_meta.solution_articles.where("id != #{article_meta.primary_article.id}").first
    build_sitemap
    translation_url = @xml.css("loc").select { |node| 
      node.text == "#{@portal.url_protocol}://#{@portal.host}/#{translated_article.language_code}/support/solutions/articles/#{translated_article.to_param}"
    }
    refute_empty translation_url, "sitemap does not contain translated published solution article"
  end

  test "sitemap does not contain translated draft solution article" do
    article_meta = create_solution_articles(create_solution_folders(create_solution_categories), 1)
    build_sitemap
    translation_url = @xml.css("loc").select { |node| 
      node.text == "#{@portal.url_protocol}://#{@portal.host}/#{@lang_list_codes.first}/support/solutions/articles/#{article_meta.to_param}"
    }
    assert_empty translation_url, "sitemap contains translated draft solution article"
  end

  test "sitemap contains translated alternate for primary solution category" do
    category_meta = create_solution_categories
    create_solution_folders(category_meta)
    build_sitemap
    primary_category_url = @xml.css("url").select { |node| 
      node.css("loc").first.text == "#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/#{category_meta.id}"
    }
    # alternates for primary category
    primary_alternate = primary_category_url.first.children.select do |element|
       alternate(element,"#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/#{category_meta.id}")
    end
    refute_empty primary_alternate, "sitemap does not contain primary alternate for primary solution category"
    
    translated_alternate = primary_category_url.first.children.select do |element|
      alternate(element,"#{@portal.url_protocol}://#{@portal.host}/#{@lang_list_codes.first}/support/solutions/#{category_meta.id}")
    end
    refute_empty translated_alternate, "sitemap does not contain translated alternate for primary solution category"
  end

  test "sitemap does not contain alternates for primary solution category when translations not present" do
    category_meta = Solution::Builder.category(create_solution_category_alone(solution_default_params(:category)))
    Solution::Builder.folder(create_solution_folder_alone(solution_default_params(:folder).merge({
      :category_id => category_meta.id })))
    build_sitemap
    category_url = @xml.css("url").select { |node| 
      node.css("loc").first.text == "#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/#{category_meta.id}"
    }
    
    alternates = category_url.first.children.select do |element|
      element.namespace.present? && element.namespace.prefix == "xhtml" && element.name == "link"
    end
    assert_empty alternates, "sitemap contains alternates when translations are not present solution category"
  end

  test "sitemap contains alternates for translated solution category" do
    category_meta = create_solution_categories
    folder_meta = create_solution_folders(category_meta)
    build_sitemap
    translated_lang = Language.find_by_key(@lang_list.first).code
    translated_category_url = @xml.css("url").select { |node| 
      node.css("loc").first.text == "#{@portal.url_protocol}://#{@portal.host}/#{translated_lang}/support/solutions/#{category_meta.id}"
    }
    # alternates for translated category
    primary_alternate = translated_category_url.first.children.select do |element|
      alternate(element,"#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/#{category_meta.id}")
    end
    refute_empty primary_alternate, "sitemap does not contain primary alternate for translated solution category"

    translated_alternate = translated_category_url.first.children.select do |element|
      alternate(element,"#{@portal.url_protocol}://#{@portal.host}/#{translated_lang}/support/solutions/#{category_meta.id}")
    end
    refute_empty translated_alternate, "sitemap does not contain translated alternate for translated solution category"   
  end

  test "sitemap contains alternates for primary solution folder when translations present" do
    folder_meta = create_solution_folders(create_solution_categories)
    build_sitemap
    translated_lang = Language.find_by_key(@lang_list.first).code
    primary_folder_url = @xml.css("url").select { |node| 
      node.css("loc").first.text == "#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/folders/#{folder_meta.id}"
    }
    # alternates for primary folder
    primary_alternate = primary_folder_url.first.children.select do |element|
       alternate(element,"#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/folders/#{folder_meta.id}")
    end
    refute_empty primary_alternate, "sitemap does not contain primary alternate for primary solution folder"

    lang_alternate = primary_folder_url.first.children.select do |element|
      alternate(element,"#{@portal.url_protocol}://#{@portal.host}/#{@lang_list_codes.first}/support/solutions/folders/#{folder_meta.id}")
    end
    refute_empty lang_alternate, "sitemap does not contain translated alternate for primary solution folder"
  end

  test "sitemap does not contain alternates for primary solution folder when translations not present" do
    category_meta = Solution::Builder.category(create_solution_category_alone(solution_default_params(:category)))
    folder_meta = Solution::Builder.folder(create_solution_folder_alone(solution_default_params(:folder).merge({
      :category_id => category_meta.id })))
    build_sitemap
    folder_url = @xml.css("url").select { |node| 
      node.css("loc").first.text == "#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/folders/#{folder_meta.id}"
    }
    alternates = folder_url.first.children.select do |element|
      element.namespace.present? && element.namespace.prefix == "xhtml" && element.name == "link"
    end
    assert_empty alternates, "sitemap contains alternates when translations are not present for solution folder"
  end

  test "sitemap contains alternates for translated solution folder" do
    folder_meta = create_solution_folders(create_solution_categories)
    build_sitemap
    translated_folder_url = @xml.css("url").select { |node| 
      node.css("loc").first.text == "#{@portal.url_protocol}://#{@portal.host}/#{@lang_list_codes.first}/support/solutions/folders/#{folder_meta.id}"
    }

    # alternates for translated folder
    primary_alternate = translated_folder_url.first.children.select do |element|
      alternate(element,"#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/folders/#{folder_meta.id}")
    end
    refute_empty primary_alternate, "sitemap does not contain primary alternate for translated solution folder"

    lang_alternate = translated_folder_url.first.children.select do |element|
      alternate(element,"#{@portal.url_protocol}://#{@portal.host}/#{@lang_list_codes.first}/support/solutions/folders/#{folder_meta.id}")
    end
    refute_empty lang_alternate, "sitemap does not contain translated alternate for translated solution folder"   
  end

  test "sitemap contains alternates for primary published solution article when published translations present" do
    article_meta = create_solution_articles(create_solution_folders(create_solution_categories), 2)
    translated_article = article_meta.solution_articles.where("id != #{article_meta.primary_article.id}").first
    primary_article = article_meta.primary_article
    build_sitemap
    primary_article_url = @xml.css("url").select { |node| 
      node.css("loc").first.text == "#{@portal.url_protocol}://#{@portal.host}/#{primary_article.language_code}/support/solutions/articles/#{primary_article.to_param}"
    }
    # alternates for primary article
    primary_alternate = primary_article_url.first.children.select do |element|
      alternate(element,"#{@portal.url_protocol}://#{@portal.host}/#{primary_article.language_code}/support/solutions/articles/#{primary_article.to_param}")
    end
    refute_empty primary_alternate, "sitemap does not contain primary alternate for primary solution article"
    
    translated_alternate = primary_article_url.first.children.select do |element|
      alternate(element,"#{@portal.url_protocol}://#{@portal.host}/#{translated_article.language_code}/support/solutions/articles/#{translated_article.to_param}")
    end
    refute_empty translated_alternate, "sitemap does not contain translated alternate for primary solution article"
  end

  test "sitemap does not contain alternates for published solution article when translations not present" do
    category_meta = Solution::Builder.category(create_solution_category_alone(solution_default_params(:category)))
    folder_meta = Solution::Builder.folder(create_solution_folder_alone(solution_default_params(:folder).merge({
      :category_id => category_meta.id })))
    article_meta = Solution::Builder.article(create_solution_article_alone(solution_default_params(:article, :title).merge({
      :folder_id => folder_meta.id, :user_id => @customer.id, :status => 2 })))
    build_sitemap

    article_url = @xml.css("url").select { |node| 
      node.css("loc").first.text == "#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/articles/#{article_meta.to_param}"
    }
    
    alternates = article_url.first.children.select do |element|
      element.namespace.present? && element.namespace.prefix == "xhtml" && element.name == "link"
    end
    assert_empty alternates, "sitemap contains alternates when translations are not present for solution articles"
  end

  test "sitemap contains alternates for published translated solution articles" do
    article_meta = create_solution_articles(create_solution_folders(create_solution_categories), 2)
    translated_article = article_meta.solution_articles.where("id != #{article_meta.primary_article.id}").first
    primary_article = article_meta.primary_article
    build_sitemap
    translation_url = @xml.css("url").select { |node| 
      node.css("loc").first.text == "#{@portal.url_protocol}://#{@portal.host}/#{translated_article.language_code}/support/solutions/articles/#{translated_article.to_param}"
    }
    # alternates for supported category
    primary_alternate = translation_url.first.children.select do |element|
      alternate(element,"#{@portal.url_protocol}://#{@portal.host}/#{primary_article.language_code}/support/solutions/articles/#{primary_article.to_param}")
    end
    refute_empty primary_alternate, "sitemap does not contain primary alternate for translated solution article"

    translated_alternate = translation_url.first.children.select do |element|
      alternate(element,"#{@portal.url_protocol}://#{@portal.host}/#{translated_article.language_code}/support/solutions/articles/#{translated_article.to_param}")
    end
    refute_empty translated_alternate, "sitemap does not contain translated alternate for translated solution article"    
  end

  test "sitemap should not contain draft article as alternates" do
    folder_meta = create_solution_folders(create_solution_categories)
    article_meta = Solution::Builder.article(create_solution_article_alone(solution_default_params(:article, :title).merge({
      :folder_id => folder_meta.id, :user_id => @customer.id })))
    Solution::Builder.article(create_solution_article_alone(solution_default_params(:article, :title).merge({
      :id => article_meta.id, :folder_id => folder_meta.id, :lang_codes => [@lang_list.first], 
      :user_id => @customer.id, :status => 1 })))
    build_sitemap
    article_url = @xml.css("url").select { |node| 
      node.css("loc").first.text == "#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/articles/#{article_meta.to_param}"
    }
    alternates = article_url.first.children.select do |element|
      element.namespace.present? && element.namespace.prefix == "xhtml" && element.name == "link"
    end
    assert_empty alternates, "sitemap contains draft article as alternates"
  end

  test "Sitemap should not contain translations when there are no portal languages" do
    @account.account_additional_settings.additional_settings[:portal_languages] = []
    @account.save
    reload(@account)
    build_sitemap
    urls = @xml.css("url")
    alternates = urls.first.children.select do |element|
      element.namespace.present? && element.namespace.prefix == "xhtml" && element.name == "link"
    end
    assert_empty alternates, "sitemap contains translations when there are no portal languages"
  end

  test "sitemap should not have solution category that is not in portal supported language" do
    @account.account_additional_settings.additional_settings[:portal_languages] = [@lang_list_codes.last]
    @account.save
    reload(@account)
    create_solution_folders(create_solution_categories)
    build_sitemap
    urls = @xml.css("loc").select { |node|
      node.text.include?("#{@lang_list_codes.first}/support/solutions") }
    assert_empty urls, "sitemap has solution category that is not in portal supported language"
  end

  test "sitemap does not have translated alternate that is not in portal suppported language" do
    @account.account_additional_settings.additional_settings[:portal_languages] = [@lang_list_codes.last]
    @account.save
    reload(@account)
    category_meta = create_solution_categories
    create_solution_folders(category_meta)
    build_sitemap
    category_url = @xml.css("url").select { |node| 
      node.css("loc").first.text == "#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/#{category_meta.id}"
    }
    translated_alternate = category_url.first.children.select do |element|
      alternate(element,"#{@portal.url_protocol}://#{@portal.host}/#{@lang_list_codes.first}/support/solutions/#{category_meta.id}")
    end
    assert_empty translated_alternate, "sitemap has translated alternate that is not in portal suppported language"
  end
  
  test "sitemap should not have solution folder that is not in portal supported language" do
    @account.account_additional_settings.additional_settings[:portal_languages] = [@lang_list_codes.last]
    @account.save
    reload(@account)
    create_solution_folders(create_solution_categories)
    build_sitemap
    urls = @xml.css("loc").select { |node|
      node.text.include?("#{@lang_list_codes.first}/support/solutions/folders") }
    assert_empty urls, "sitemap has solution folder that is not in portal supported language"
  end

  test "sitemap should not have solution folder translations that is not in portal supported language" do
    @account.account_additional_settings.additional_settings[:portal_languages] = [@lang_list_codes.last]
    @account.save
    reload(@account)
    folder_meta = create_solution_folders(create_solution_categories)
    build_sitemap
    folder_url = @xml.css("url").select { |node| 
      node.css("loc").first.text == "#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/folders/#{folder_meta.id}"
    }
    translated_alternate = folder_url.first.children.select do |element|
      alternate(element,"#{@portal.url_protocol}://#{@portal.host}/#{@lang_list_codes.first}/support/solutions/folders/#{folder_meta.id}")
    end
    assert_empty translated_alternate, "sitemap has translated alternates that is not in portal suppported language"
  end

  test "sitemap should not have solution article that is not in portal supported language" do
    @account.account_additional_settings.additional_settings[:portal_languages] = [@lang_list_codes.last]
    @account.save
    reload(@account)
    create_solution_articles(create_solution_folders(create_solution_categories), 2)
    build_sitemap
    urls = @xml.css("loc").select { |node|
      node.text.include?("#{@lang_list_codes.first}/support/solutions/articles") }
    assert_empty urls, "sitemap has solution folder that is not in portal supported language"
  end

  test "sitemap should not have solution article translations that is not in portal supported language" do
    @account.account_additional_settings.additional_settings[:portal_languages] = [@lang_list_codes.last]
    @account.save
    reload(@account)
    article_meta = create_solution_articles(create_solution_folders(create_solution_categories), 2)
    translated_article = article_meta.solution_articles.where("id != #{article_meta.primary_article.id}").first
    primary_article = article_meta.primary_article
    build_sitemap
    article_url = @xml.css("url").select { |node| 
      node.css("loc").first.text == "#{@portal.url_protocol}://#{@portal.host}/#{@account.language}/support/solutions/articles/#{primary_article.to_param}"
    }
    translated_alternate = article_url.first.children.select do |element|
      alternate(element,"#{@portal.url_protocol}://#{@portal.host}/#{translated_article.language_code}/support/solutions/articles/#{translated_article.to_param}")
    end
    assert_empty translated_alternate, "sitemap has translated alternates that is not in portal suppported language"
  end

  # Discussions
  test "No translated discussion urls should be present" do
    create_test_forum(create_test_category)
    build_sitemap
    urls = @xml.css("url")
    alternates = urls.first.children.select do |element|
      element.namespace.present? && element.namespace.prefix == "xhtml" && element.name == "link" && element["href"].include?("/support/discussions")
    end
    assert_empty alternates, "sitemap discussions contain translations"
  end

  test "No language should be present in the discussion urls" do
    create_test_forum(create_test_category)
    build_sitemap
    lang_urls = @xml.css("loc").select { |node|
      node.text.include?("#{@lang_list_codes.first}/support/discussions") || node.text.include?("#{@account.language}/support/discussions") }
    assert_empty lang_urls, "sitemap contains language in discussion urls"
  end

end
