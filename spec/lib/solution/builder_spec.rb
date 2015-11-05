require 'spec_helper'

RSpec.describe Solution::Builder do 

  setup :activate_authlogic
  self.use_transactional_fixtures = false

  describe "Solution::Builder" do

    before(:all) do
      @lang_list = Language.all.map(&:to_key).sample(15) - [@account.language]
      @initial_lang_list = @account.account_additional_settings.supported_languages
      @account.account_additional_settings.supported_languages = @lang_list
      @account.save
    end

    describe "category" do

      it "should be created" do
        params = create_category_alone(default_params(:category))
        category_meta = Solution::Builder.category(params)
        expect(category_meta.id).to be_present
        expect(category_meta.solution_categories.count).to eql(1)
        expect(category_meta.primary_category).to be_present
        expect(category_meta.primary_category.name).to be_eql(params[:solution_category_meta][:primary_category][:name])
        category_meta.destroy
      end

      it "should be updated" do
        params = create_category_alone(default_params(:category))
        category_meta = Solution::Builder.category(params)
        expect(category_meta.id).to be_present
        initial_meta_id = category_meta.id
        update_params = {
          :solution_category_meta => {
            :id => category_meta.id,
            :is_default => true,
            :primary_category => {
              :name => "#Updated #{default_params(:category)[:name]}"
            }
          }
        }
        category_meta = Solution::Builder.category(update_params)
        expect(category_meta.primary_category.name).to be_eql(update_params[:solution_category_meta][:primary_category][:name])
        #Should not allow user to create default categories (or update existing to default also)
        #only one default category should exist
        if @account.solution_category_meta.where(:is_default => true).first.present?
          expect(category_meta.is_default).to be_eql(false) 
        else
          expect(category_meta.is_default).to be_eql(true) 
        end
        expect(category_meta.id).to be_eql(initial_meta_id)
        category_meta.destroy
      end

      it "should be created(multiple versions)" do
        lang_vers = @lang_list.sample(5) + [:primary]
        params = create_category_alone(default_params(:category).merge({
          :lang_codes => lang_vers
          }))
        category_meta = Solution::Builder.category(params)
        expect(category_meta.solution_categories.count).to eql(lang_vers.size)
        check_updates(lang_vers, category_meta, params, type = :category)
        category_meta.destroy
      end

      it "should be updated(of specific version)" do
        update_lang_vers = @lang_list.sample(3) + [:primary]
        params = create_category_alone(default_params(:category).merge({
          :lang_codes => update_lang_vers
          }))
        category_meta = Solution::Builder.category(params)
        check_updates(update_lang_vers, category_meta, params)

        update_params = { :solution_category_meta => { :id => category_meta.id } }
        (update_lang_vers).each do |lang|
          update_params[:solution_category_meta].merge!({
            "#{lang}_category" => {
              :name => "New Category Name - #{Faker::Name.name}"
            }
          })
        end
        category_meta = Solution::Builder.category(update_params)
        check_updates((update_lang_vers - [:primary]), category_meta, update_params, :category)
        category_meta.destroy
      end

      it "should not be created without primary" do
        lang_vers = @lang_list.sample(3)
        params = create_category_alone(default_params(:category).merge({
          :lang_codes => lang_vers
          }))
        category_meta = Solution::Builder.category(params)
        expect(category_meta.id).not_to be_present
        expect(category_meta.primary_category).not_to be_present
      end

      it "should be associated with multiple portals" do
        p1 = create_product({ :portal_url => "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}" })
        p2 = create_product({ :portal_url => "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}" })
        p_ids = [p1.portal.id, p2.portal.id]
        params = create_category_alone(default_params(:category))
        params[:solution_category_meta].merge!({:portal_ids => p_ids})
        category_meta = Solution::Builder.category(params)
        visible_portals = category_meta.portal_ids
        p_ids.each do |p_id|
          expect(visible_portals).to include(p_id)
        end
      end

      it "should be created which is associated to default portal if no portal ids given" do
        params = create_category_alone(default_params(:category))
        category_meta = Solution::Builder.category(params)
        expect(category_meta.id).to be_present
        expect(category_meta.portal_ids.count).to be_eql(1)
        expect(category_meta.portal_ids).to include(@account.main_portal.id)
      end

    end

    describe "folder" do
      before(:all) do
        @folder_lang_ver = @lang_list.sample(10)
        params = create_category_alone(default_params(:category).merge({
          :lang_codes => @folder_lang_ver + [:primary]
          }))
        @category_meta = Solution::Builder.category(params)
        params = create_category_alone(default_params(:category).merge({
          :lang_codes => @folder_lang_ver + [:primary]
          }))
        @category_meta2 = Solution::Builder.category(params)
      end

      it "should be created" do
        params = create_folder_alone(default_params(:folder).merge({:category_id => @category_meta.id}))
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.id).to be_present
        expect(folder_meta.primary_folder).to be_present
        expect(folder_meta.primary_folder.name).to be_eql(params[:solution_folder_meta][:primary_folder][:name])
      end

      it "should be updated" do
        params = create_folder_alone(default_params(:folder).merge({:category_id => @category_meta.id}))
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.id).to be_present
        expect(folder_meta.primary_folder).to be_present
        update_params = {
          :solution_folder_meta => {
            :id => folder_meta.id,
            :primary_folder => {
              :name => "New name #{Faker::Name.name}"
            } 
          }
        }
        folder_meta = Solution::Builder.folder(update_params)
        expect(folder_meta.primary_folder.name).to be_eql(update_params[:solution_folder_meta][:primary_folder][:name])
      end

      it "should update the category of the folder" do
        params = create_folder_alone(default_params(:folder).merge({:category_id => @category_meta.id}))
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.solution_category_meta.id).to be_eql(@category_meta.id)
        update_params = {
          :solution_folder_meta => {
            :id => folder_meta.id,
            :solution_category_meta_id => @category_meta2.id,
            :primary_folder => {
              :name => "New name #{Faker::Name.name}"
            } 
          }
        }
        folder_meta = Solution::Builder.folder(update_params)
        expect(folder_meta.primary_folder.name).to be_eql(update_params[:solution_folder_meta][:primary_folder][:name])
        expect(folder_meta.solution_category_meta.id).to be_eql(@category_meta2.id)
      end

      it "should be created (multiple versions)" do
        lang_vers = @folder_lang_ver.sample(5)
        params = create_folder_alone(default_params(:folder).merge(
          {   
            :category_id => @category_meta.id,
            :visibility => 2,
            :lang_codes => lang_vers + [:primary]
          }))
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.id).to be_present
        expect(folder_meta.solution_folders.count).not_to be_eql(0)
        check_updates(lang_vers + [:primary], folder_meta, params, type = :folder)
      end

      it "should be updated (of specific version)" do
        lang_vers = @folder_lang_ver.sample(3)
        params = create_folder_alone(default_params(:folder).merge(
          {   
            :category_id => @category_meta.id,
            :visibility => 2,
            :lang_codes => lang_vers + [:primary]
          }))
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.id).to be_present
        update_params = { :solution_folder_meta => { :id => folder_meta.id } }
        lang_vers.each do |lang|
          update_params[:solution_folder_meta].merge!({
            "#{lang}_folder" => {
              :name => "New name #{Faker::Name.name}"
            }
          })
        end
        folder_meta = Solution::Builder.folder(update_params.deep_symbolize_keys!)
        check_updates(lang_vers, folder_meta, update_params, type = :folder)
      end

      it "should not be created without primary version" do
        lang_vers = @folder_lang_ver.sample(3)
        params = create_folder_alone(default_params(:folder).merge(
          {   
            :category_id => @category_meta.id,
            :visibility => 2,
            :lang_codes => lang_vers
          }))
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.id).not_to be_present
        expect(folder_meta.primary_folder).not_to be_present
      end

      it "should be created along with category version" do
        remaining_langs = @lang_list - @folder_lang_ver
        new_ver_lang = remaining_langs.sample(2)
        category_params = create_category_alone(default_params(:category).merge({
          :lang_codes => new_ver_lang,
          :id => @category_meta.id 
        }))
        folder_params = create_folder_alone(default_params(:folder).merge({
          :lang_codes => new_ver_lang + [:primary],
          :category_id => @category_meta.id
          }))
        folder_params[:solution_folder_meta].merge!(category_params)
        folder_meta = Solution::Builder.folder(folder_params)
        expect(folder_meta.id).to be_present
        check_updates(new_ver_lang, folder_meta, folder_params, type = :folder)
        check_updates(new_ver_lang, folder_meta.solution_category_meta, category_params, type = :category)
      end

      it "should be created along with brand new category" do
        new_ver_lang = @lang_list.sample(3)
        category_params = create_category_alone(default_params(:category).merge({
          :lang_codes => new_ver_lang + [:primary]
        }))
        folder_params = create_folder_alone(default_params(:folder).merge({
          :lang_codes => new_ver_lang + [:primary]
          }))
        folder_params[:solution_folder_meta].merge!(category_params)
        folder_meta = Solution::Builder.folder(folder_params)
        expect(folder_meta.id).to be_present
        check_updates(new_ver_lang, folder_meta, folder_params, type = :folder)
        check_updates(new_ver_lang, folder_meta.solution_category_meta, category_params, type = :category)
        folder_meta.solution_category_meta.destroy
      end

      it "should change the visibility to company and make necc assoc" do\
        c_ids = []
        rand(2..7).times do 
          company = Company.new(:name => Faker::Name.name)
          company.account_id = @account.id
          company.save
          c_ids << company.id
        end
        params = create_folder_alone(default_params(:folder).merge({
          :category_id => @category_meta.id,
          :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]
        }))
        params[:solution_folder_meta].merge!({ :customer_folders_attributes => c_ids })
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.visibility).to be_eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users])
        expect(folder_meta.customer_ids).to include(*c_ids)
      end

      after(:all) do
        @category_meta.destroy
      end
    end

    describe "article" do

      before(:all) do       
        @article_lang_ver = @lang_list.sample(10)
        params = create_category_alone(default_params(:category).merge({
          :lang_codes => @article_lang_ver + [:primary]
          }))
        @category_meta = Solution::Builder.category(params)
        f_params = create_folder_alone(default_params(:folder).merge(
          {   
            :category_id => @category_meta.id,
            :visibility => 2,
            :lang_codes => @article_lang_ver + [:primary]
          }))
        @folder_meta = Solution::Builder.folder(f_params)
        f_params = create_folder_alone(default_params(:folder).merge({:category_id => @category_meta.id}))
        @folder_meta2 = Solution::Builder.folder(f_params)
        @remaining_langs = @lang_list - @article_lang_ver
      end
    
      it "should be created" do
        params = create_article_alone(default_params(:article, :title).merge({
          :folder_id => @folder_meta.id
          }))
        article_meta = Solution::Builder.article(params.deep_symbolize_keys!)
        expect(article_meta.id).to be_present
        expect(article_meta.solution_articles.count).to eql(1)
        expect(article_meta.primary_article.title).to be_eql(params[:solution_article_meta][:primary_article][:title]) 
      end

      it "should be updated" do
        params = create_article_alone(default_params(:article, :title).merge({
          :folder_id => @folder_meta.id
          }))
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        update_params = {
          :solution_article_meta => {
            :id => article_meta.id,
            :folder_id => @folder_meta,
            :primary_article => {
              :title => "New Article #{Faker::Name.name}"
            } 
          }
        }
        article_meta = Solution::Builder.article(update_params.deep_symbolize_keys!)
        expect(article_meta.id).to be_present
        expect(article_meta.primary_article.title).to be_eql(update_params[:solution_article_meta][:primary_article][:title])
      end

      it "should be created(multiple versions)" do
        lang_vers = @article_lang_ver.sample(5)
        params = create_article_alone(default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers + [:primary]
          }))
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        check_updates(lang_vers + [:primary], article_meta, params, :article)
      end

      it "should be updated(of specific version)" do
        lang_vers = @article_lang_ver.sample(3)
        params = create_article_alone(default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers + [:primary]
          }))
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        update_params = { :solution_article_meta => {:id => article_meta.id } }
        lang_vers.each do |lang|
          update_params[:solution_article_meta].merge!({
            "#{lang}_article" => {
              :title => "#Update - #{Faker::Name.name}"
            }
          })
        end
        article_meta = Solution::Builder.article(update_params.deep_symbolize_keys!)
        check_updates(lang_vers, article_meta, update_params, :article)
      end

      it "should change the folder" do
        params = create_article_alone(default_params(:article, :title).merge({
          :folder_id => @folder_meta.id
          }))
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        params = create_article_alone(default_params(:article, :title).merge({ :id => article_meta.id,:folder_id => @folder_meta2.id}))
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        expect(article_meta.solution_folder_meta.id).to be_eql(@folder_meta2.id)
      end

      it "should not be created without primary" do
        lang_vers = @article_lang_ver.sample(3)
        params = create_article_alone(default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers
          }))
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).not_to be_present
        expect(article_meta.primary_article).not_to be_present

        # Can we check for the error that we are expecting in all such cases
      end

      it "should create normal attachments" do
        file = fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)
        params = create_article_alone(default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :attachments => [{:resource => file, :description => Faker::Lorem.characters(10)}]
          }))
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        expect(article_meta.primary_article.attachments.count).to be_eql(1)
        expect(article_meta.primary_article.attachments.first.description).to be_eql(params[:solution_article_meta][:primary_article][:attachments][0][:description])
      end

      it "should create cloud file attachments" do
        params = create_article_alone(default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :cloud_file_attachments => ['{ "name": "1ba83043-aba9-46fe-aa39-4ff695d9ea24 copy.png",
              "link": "https://app.box.com/s/7cq8tkphkhm66dbpi2b0ok67gut7eiux",
              "provider": "box" }']
          })).deep_symbolize_keys
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        expect(article_meta.primary_article.cloud_files.count).to be_eql(1)
        attachment = ActiveSupport::JSON.decode(params[:solution_article_meta][:primary_article][:cloud_file_attachments][0])
        expect(article_meta.primary_article.cloud_files.first.filename).to be_eql(attachment['name'])
      end

      it "should be created with folder version" do
        new_ver_lang = @remaining_langs.sample(2)
        folder_params = create_folder_alone(default_params(:folder).merge({
          :lang_codes => new_ver_lang,
          :id => @folder_meta.id
          }))
        params = create_article_alone(default_params(:article, :title).merge({
          :lang_codes => new_ver_lang + [:primary],
          :folder_id => @folder_meta.id
          }))
        params[:solution_article_meta].merge!(folder_params)
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        check_updates(new_ver_lang, article_meta, params, :article)
        check_updates(new_ver_lang, article_meta.solution_folder_meta, folder_params, :folder)
      end

      it "should be created with brand new folder" do
        new_ver_lang = @remaining_langs.sample(2) + [:primary]
        folder_params = create_folder_alone(default_params(:folder).merge({
          :lang_codes => new_ver_lang,
          :category_id => @category_meta.id
          }))
        params = create_article_alone(default_params(:article, :title).merge({
          :lang_codes => new_ver_lang
          }))
        params[:solution_article_meta].merge!(folder_params)
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        check_updates(new_ver_lang, article_meta, params, :article)
        check_updates(new_ver_lang, article_meta.solution_folder_meta, folder_params, :folder)
        article_meta.solution_folder_meta.destroy
      end

      it "should be created with folder & category versions" do
        new_ver_lang = @remaining_langs.sample(2)
        category_params = create_category_alone(default_params(:category).merge({
          :lang_codes => new_ver_lang,
          :id => @category_meta.id 
        }))
        folder_params = create_folder_alone(default_params(:folder).merge({
          :lang_codes => new_ver_lang,
          :id => @folder_meta.id,
          :category_id => @category_meta.id
          }))
        folder_params[:solution_folder_meta].merge!(category_params)
        params = create_article_alone(default_params(:article, :title).merge({
          :lang_codes => new_ver_lang + [:primary],
          :folder_id => @folder_meta.id
          }))
        params[:solution_article_meta].merge!(folder_params)
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        check_updates(new_ver_lang, article_meta, params, :article)
        check_updates(new_ver_lang, article_meta.solution_folder_meta, folder_params, :folder)
        check_updates(new_ver_lang, article_meta.solution_folder_meta.solution_category_meta, category_params, :category)
      end

      it "should be created with brand new folder & category" do
        new_ver_lang = @remaining_langs.sample(2) + [:primary]
        category_params = create_category_alone(default_params(:category).merge({
          :lang_codes => new_ver_lang
        }))
        folder_params = create_folder_alone(default_params(:folder).merge({
          :lang_codes => new_ver_lang
          }))
        folder_params[:solution_folder_meta].merge!(category_params)
        params = create_article_alone(default_params(:article, :title).merge({
          :lang_codes => new_ver_lang
          }))
        params[:solution_article_meta].merge!(folder_params)
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        check_updates(new_ver_lang, article_meta, params, :article)
        check_updates(new_ver_lang, article_meta.solution_folder_meta, folder_params, :folder)
        check_updates(new_ver_lang, article_meta.solution_folder_meta.solution_category_meta, category_params, :category)
        article_meta.solution_folder_meta.solution_category_meta.destroy
      end
    end

  end

  describe "Using old param structure" do

    describe "category" do

      it "should be created" do
        c_params = api_category
        category_meta = Solution::Builder.category(c_params)
        expect(category_meta.id).to be_present
        expect(category_meta.primary_category).to be_present
        expect(category_meta.primary_category.name).to be_eql(c_params[:solution_category][:name])
        expect(category_meta.is_default).to be_eql(false)
      end

      it "should be updated" do
        category_meta = Solution::Builder.category(api_category)
        expect(category_meta.id).to be_present
        params = api_category({:name => "New name #{Faker::Name.name}"})
        params[:solution_category].merge!({:id => category_meta.id})
        category_meta = Solution::Builder.category(params)
        expect(category_meta.primary_category.name).to be_eql(params[:solution_category][:name])
        expect(category_meta.portal_ids).to include(@account.main_portal.id)
      end

    end

    describe "folder" do
      
      before(:all) do
        @category_meta = Solution::Builder.category(api_category)
        @category_meta2 = Solution::Builder.category(api_category)
      end

      it "should be created" do
        params = api_folder
        params[:solution_folder].merge!(:category_id => @category_meta.id)
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.id).to be_present
        expect(folder_meta.primary_folder).to be_present
      end

      it "should be updated" do
        params = api_folder
        params[:solution_folder].merge!(:category_id => @category_meta.id)
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.id).to be_present
        initial_meta_id = folder_meta.id
        params = api_folder({:name => "New name #{Faker::Name.name}"})
        params[:solution_folder].merge!({:category_id => @category_meta2.id, :id => folder_meta.id})
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.primary_folder).to be_present
        expect(folder_meta.primary_folder.name).to be_eql(params[:solution_folder][:name])
        expect(folder_meta.solution_category_meta_id).to be_eql(@category_meta2.id)
        expect(folder_meta.id).to be_eql(initial_meta_id)
      end

      it "should be updated with new visibility (company)" do
        params = api_folder
        params[:solution_folder].merge!(:category_id => @category_meta.id)
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.id).to be_present
        initial_meta_id = folder_meta.id

        c_ids = []
        rand(2..7).times do 
          company = Company.new(:name => Faker::Name.name)
          company.account_id = @account.id
          company.save
          c_ids << company.id
        end

        params = api_folder({:name => "New name #{Faker::Name.name}"})
        params[:solution_folder].merge!({
          :category_id => @category_meta2.id, 
          :id => folder_meta.id,
          :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users],
          :customer_folders_attributes => c_ids
          })
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.primary_folder).to be_present
        expect(folder_meta.primary_folder.name).to be_eql(params[:solution_folder][:name])
        expect(folder_meta.solution_category_meta_id).to be_eql(@category_meta2.id)
        expect(folder_meta.id).to be_eql(initial_meta_id)
        expect(folder_meta.visibility).to be_eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users])
        expect(folder_meta.customer_ids).to include(*c_ids)
      end

    end

    describe "article" do
      
      before(:all) do
        @category_meta = Solution::Builder.category(api_category)
        params = api_folder
        params[:solution_folder].merge!(:category_id => @category_meta.id)
        @folder_meta = Solution::Builder.folder(params)
        params = api_folder
        params[:solution_folder].merge!(:category_id => @category_meta.id)
        @folder_meta2 = Solution::Builder.folder(params)
      end
      
      it "should create" do
        params = api_article({:folder_id => @folder_meta.id})
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        expect(article_meta.primary_article).to be_present
        expect(article_meta.primary_article.title).to be_eql(params[:solution_article][:title])
      end

      it "should update" do
        params = api_article({:folder_id => @folder_meta.id})
        article_meta = Solution::Builder.article(params)
        expect(article_meta.solution_folder_meta_id).to be_eql(@folder_meta.id)
        expect(article_meta.art_type).to be_eql(2)
        expect(article_meta.primary_article.status).to be_eql(1)
        update_params = api_article({
          :folder_id => @folder_meta2.id,
          :id => article_meta.id,
          :status => 2,
          :art_type => 1
        })
        article_meta = Solution::Builder.article(update_params)
        expect(article_meta.id).to be_present
        expect(article_meta.primary_article).to be_present
        expect(article_meta.primary_article.title).to be_eql(update_params[:solution_article][:title])
        expect(article_meta.solution_folder_meta_id).to be_eql(@folder_meta2.id)
        expect(article_meta.art_type).to be_eql(1)
        expect(article_meta.primary_article.status).to be_eql(2)
      end

    end

  end

  def default_params(base, name = :name)
    {
      "#{name}" => "#{base} #{(Time.now.to_f * 1000).to_i} on #{Faker::Name.name} - #{Time.now.to_s}",
      "description" => "#{Faker::Lorem.sentence(rand(1..10))}"
    }.deep_symbolize_keys
  end

  def create_category_alone(params = {})
    {
      :solution_category_meta => {
        :id => params[:id] || nil,
      }.merge(lang_ver_hash(:category, params[:lang_codes], params.except(:lang_codes, :id)))
    }.deep_symbolize_keys
  end

  def create_folder_alone(params = {})
    {
      :solution_folder_meta => {
        :id => params[:id] || nil,
        :visibility => params[:visibility] || 1,
        :solution_category_meta_id => params[:category_id] || nil,
      }.merge(lang_ver_hash(:folder, params[:lang_codes], params.except(:lang_codes, :id, :category_id, :visibility)))
    }.deep_symbolize_keys
  end

  def create_article_alone(params = {})
    params[:user_id] = @agent.id if params[:user_id].blank?
    {
      :solution_article_meta => {
        :id => params[:id] || nil,
        :art_type => params[:art_type] || 1,
        :solution_folder_meta_id => params[:folder_id] || nil
      }.merge(lang_ver_hash(:article, params[:lang_codes], params.except(:lang_codes, :folder_id, :art_type, :id)))
    }.deep_symbolize_keys
  end

  def lang_ver_hash(base, lang_codes, params = {})
    final = {}
    lang_codes = [:primary] unless lang_codes.present?
    lang_codes.each do |lang_code|
      key = params.keys.include?(:name) ? :name : :title
      final["#{lang_code}_#{base}"] = params.dup
      final["#{lang_code}_#{base}"][key] = "#{lang_code} #{params[key]}" if key.present?
    end
    final.deep_symbolize_keys
  end

  def create_version_tree_from_article(params = {})
    sa = create_article_alone(params[:solution_article])
    sf = create_folder_alone(params[:solution_folder])
    sc = create_category_alone(params[:solution_category])
    sa.merge!(sf.merge(sc)).deep_symbolize_keys
  end

  def api_article(params = {})
    {
      "solution_article" => {
        "title" => params[:title] || "Article on #{(Time.now.to_f * 1000).to_i} #{Faker::Name.name}",
        "status" => params[:status] || 1,
        "art_type" => params[:art_type] || 2,
        "description" => params[:description] || "#{Faker::Lorem.sentence(3)}",
        "folder_id" => params[:folder_id] || nil,
        "user_id" => @agent.id
      },
      "tags" => params[:tags] || { "name" => "tag1, tag2"}
    }.deep_symbolize_keys
  end

  def api_folder(params = {})
    {
       "solution_folder" => {
          "name" => params[:name] || "Folder on #{(Time.now.to_f * 1000).to_i} #{Faker::Name.name}",
          "visibility" => params[:visibility] || 1,
          "description" => params[:description] || "#{Faker::Lorem.sentence(2)}"
       }
    }.deep_symbolize_keys
  end

  def api_category(params = {})
    {
      "solution_category" => {
        "name" => params[:name] || "Category on #{(Time.now.to_f * 1000).to_i} #{Faker::Name.name}",
        "description" => params[:description] || "#{Faker::Lorem.sentence(1)}"
      }
    }.deep_symbolize_keys
  end

  def check_updates(lang_vers, meta_obj, params, type = :category)
    params.deep_symbolize_keys!
    name_type = type == :article ? :title : :name
    lang_vers.each do |lang|
      sol_obj_ver = meta_obj.send("#{lang}_#{type}")
      expect(sol_obj_ver).to be_present
      expect(sol_obj_ver.send("#{name_type}")).to be_eql(params["solution_#{type}_meta".to_sym]["#{lang}_#{type}".to_sym][name_type])
    end
  end

end