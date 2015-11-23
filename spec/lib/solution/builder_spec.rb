require 'spec_helper'

RSpec.describe Solution::Builder do 

  setup :activate_authlogic
  self.use_transactional_fixtures = false

  describe "Solution::Builder" do

    before(:all) do
      @lang_list = Language.all.map(&:to_key).sample(25) - [@account.language]
      @initial_lang_list = @account.account_additional_settings.supported_languages
      @account.account_additional_settings.supported_languages = @lang_list
      @account.save
    end

    describe "category" do

      it "should be created" do
        params = create_solution_category_alone(solution_default_params(:category))
        category_meta = Solution::Builder.category(params)
        expect(category_meta.id).to be_present
        expect(category_meta.solution_categories.count).to eql(1)
        expect(category_meta.primary_category).to be_present
        expect(category_meta.primary_category.name).to be_eql(params[:solution_category_meta][:primary_category][:name])
        category_meta.destroy
      end

      it "should be updated" do
        params = create_solution_category_alone(solution_default_params(:category))
        category_meta = Solution::Builder.category(params)
        expect(category_meta.id).to be_present
        initial_meta_id = category_meta.id
        update_params = {
          :solution_category_meta => {
            :id => category_meta.id,
            :is_default => true,
            :primary_category => {
              :name => "#Updated #{solution_default_params(:category)[:name]}"
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
        params = create_solution_category_alone(solution_default_params(:category).merge({
          :lang_codes => lang_vers
          }))
        category_meta = Solution::Builder.category(params)
        expect(category_meta.solution_categories.count).to eql(lang_vers.size)
        solution_check_updates(lang_vers, category_meta, params, type = :category)
        category_meta.destroy
      end

      it "should be updated(of specific version)" do
        update_lang_vers = @lang_list.sample(3) + [:primary]
        params = create_solution_category_alone(solution_default_params(:category).merge({
          :lang_codes => update_lang_vers
          }))
        category_meta = Solution::Builder.category(params)
        solution_check_updates(update_lang_vers, category_meta, params)

        old_ver_id = category_meta.send("#{update_lang_vers[1]}_category").id

        update_params = { :solution_category_meta => { :id => category_meta.id } }
        (update_lang_vers).each do |lang|
          update_params[:solution_category_meta].merge!({
            "#{lang}_category" => {
              :name => "New Category Name - #{Faker::Name.name}"
            }
          })
        end
        category_meta = Solution::Builder.category(update_params)
        solution_check_updates((update_lang_vers - [:primary]), category_meta, update_params, :category)
        new_ver_id = category_meta.send("#{update_lang_vers[1]}_category").id
        expect(old_ver_id).to be_eql(new_ver_id)
        category_meta.destroy
      end

      it "should not be created without primary" do
        lang_vers = @lang_list.sample(3)
        params = create_solution_category_alone(solution_default_params(:category).merge({
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
        params = create_solution_category_alone(solution_default_params(:category))
        params[:solution_category_meta].merge!({:portal_ids => p_ids})
        category_meta = Solution::Builder.category(params)
        visible_portals = category_meta.portal_ids
        p_ids.each do |p_id|
          expect(visible_portals).to include(p_id)
        end
        category_meta.destroy
      end

      it "should be created which is associated to default portal if no portal ids given" do
        params = create_solution_category_alone(solution_default_params(:category))
        category_meta = Solution::Builder.category(params)
        expect(category_meta.id).to be_present
        expect(category_meta.portal_ids.count).to be_eql(1)
        expect(category_meta.portal_ids).to include(@account.main_portal.id)
        category_meta.destroy
      end

    end

    describe "folder" do
      before(:example) do
        @folder_lang_ver = @lang_list.sample(10)
        params = create_solution_category_alone(solution_default_params(:category).merge({
          :lang_codes => @folder_lang_ver + [:primary]
          }))
        @category_meta = Solution::Builder.category(params)
        params = create_solution_category_alone(solution_default_params(:category).merge({
          :lang_codes => @folder_lang_ver + [:primary]
          }))
        @category_meta2 = Solution::Builder.category(params)
      end

      it "should be created" do
        params = create_solution_folder_alone(solution_default_params(:folder).merge({:category_id => @category_meta.id}))
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.id).to be_present
        expect(folder_meta.primary_folder).to be_present
        expect(folder_meta.primary_folder.name).to be_eql(params[:solution_folder_meta][:primary_folder][:name])
      end

      it "should be updated" do
        params = create_solution_folder_alone(solution_default_params(:folder).merge({:category_id => @category_meta.id}))
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
        params = create_solution_folder_alone(solution_default_params(:folder).merge({:category_id => @category_meta.id}))
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
        params = create_solution_folder_alone(solution_default_params(:folder).merge(
          {   
            :category_id => @category_meta.id,
            :visibility => 2,
            :lang_codes => lang_vers + [:primary]
          }))
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.id).to be_present
        expect(folder_meta.solution_folders.count).not_to be_eql(0)
        solution_check_updates(lang_vers + [:primary], folder_meta, params, type = :folder)
      end

      it "should be updated (of specific version)" do
        lang_vers = @folder_lang_ver.sample(3)
        params = create_solution_folder_alone(solution_default_params(:folder).merge(
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
        solution_check_updates(lang_vers, folder_meta, update_params, type = :folder)
      end

      it "should not be created without primary version" do
        lang_vers = @folder_lang_ver.sample(3)
        params = create_solution_folder_alone(solution_default_params(:folder).merge(
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
        category_params = create_solution_category_alone(solution_default_params(:category).merge({
          :lang_codes => new_ver_lang,
          :id => @category_meta.id 
        }))
        folder_params = create_solution_folder_alone(solution_default_params(:folder).merge({
          :lang_codes => new_ver_lang + [:primary],
          :category_id => @category_meta.id
          }))
        folder_params[:solution_folder_meta].merge!(category_params)
        folder_meta = Solution::Builder.folder(folder_params)
        expect(folder_meta.id).to be_present
        solution_check_updates(new_ver_lang, folder_meta, folder_params, type = :folder)
        solution_check_updates(new_ver_lang, folder_meta.solution_category_meta, category_params, type = :category)
      end

      it "should be created along with brand new category" do
        new_ver_lang = @lang_list.sample(3)
        category_params = create_solution_category_alone(solution_default_params(:category).merge({
          :lang_codes => new_ver_lang + [:primary]
        }))
        folder_params = create_solution_folder_alone(solution_default_params(:folder).merge({
          :lang_codes => new_ver_lang + [:primary]
          }))
        folder_params[:solution_folder_meta].merge!(category_params)
        folder_meta = Solution::Builder.folder(folder_params)
        expect(folder_meta.id).to be_present
        solution_check_updates(new_ver_lang, folder_meta, folder_params, type = :folder)
        solution_check_updates(new_ver_lang, folder_meta.solution_category_meta, category_params, type = :category)
        folder_meta.solution_category_meta.destroy
      end

      it "should change the visibility to company and make necc assoc" do
        c_ids = []
        rand(2..7).times do 
          company = Company.new(:name => Faker::Name.name)
          company.account_id = @account.id
          company.save
          c_ids << company.id
        end
        params = create_solution_folder_alone(solution_default_params(:folder).merge({
          :category_id => @category_meta.id,
          :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]
        }))
        params[:solution_folder_meta].merge!({ :customer_folders_attributes => c_ids })
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.visibility).to be_eql(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users])
        expect(folder_meta.customer_ids).to include(*c_ids)
      end

      after(:example) do
        @category_meta.destroy
        @category_meta2.destroy
      end
    end

    describe "article" do

      before(:example) do       
        @article_lang_ver = @lang_list.sample(10)
        params = create_solution_category_alone(solution_default_params(:category).merge({
          :lang_codes => @article_lang_ver + [:primary]
          }))
        @category_meta = Solution::Builder.category(params)
        f_params = create_solution_folder_alone(solution_default_params(:folder).merge(
          {   
            :category_id => @category_meta.id,
            :visibility => 2,
            :lang_codes => @article_lang_ver + [:primary]
          }))
        @folder_meta = Solution::Builder.folder(f_params)
        f_params = create_solution_folder_alone(solution_default_params(:folder).merge({:category_id => @category_meta.id}))
        @folder_meta2 = Solution::Builder.folder(f_params)
        @remaining_langs = @lang_list - @article_lang_ver
      end
    
      it "should be created" do
        params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id
          }))
        article_meta = Solution::Builder.article(params.deep_symbolize_keys!)
        expect(article_meta.id).to be_present
        expect(article_meta.solution_articles.count).to eql(1)
        expect(article_meta.primary_article.title).to be_eql(params[:solution_article_meta][:primary_article][:title]) 
      end

      it "should be updated" do
        params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id
          }))
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        update_params = {
          :solution_article_meta => {
            :id => article_meta.id,
            :folder_id => @folder_meta.id,
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
        params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers + [:primary]
          }))
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        solution_check_updates(lang_vers + [:primary], article_meta, params, :article)
      end

      it "should be updated(of specific version)" do
        lang_vers = @article_lang_ver.sample(3)
        params = create_solution_article_alone(solution_default_params(:article, :title).merge({
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
        solution_check_updates(lang_vers, article_meta, update_params, :article)
      end

      it "should change the folder" do
        params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id
          }))
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        params = create_solution_article_alone(solution_default_params(:article, :title).merge({ :id => article_meta.id,:folder_id => @folder_meta2.id}))
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        expect(article_meta.solution_folder_meta.id).to be_eql(@folder_meta2.id)
      end

      it "should not be created without primary" do
        lang_vers = @article_lang_ver.sample(3)
        params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers
          }))
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).not_to be_present
        expect(article_meta.primary_article).not_to be_present
        expect(article_meta.errors.full_messages.join('')).to include("Primary version attributes can\'t be blank")
      end

      it "should create normal attachments" do
        file = fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)
        params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :attachments => [{:resource => file, :description => Faker::Lorem.characters(10)}]
          }))
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        expect(article_meta.primary_article.attachments.count).to be_eql(1)
        expect(article_meta.primary_article.attachments.first.description).to be_eql(params[:solution_article_meta][:primary_article][:attachments][0][:description])
      end

      it "should create cloud file attachments" do
        params = create_solution_article_alone(solution_default_params(:article, :title).merge({
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
        folder_params = create_solution_folder_alone(solution_default_params(:folder).merge({
          :lang_codes => new_ver_lang,
          :id => @folder_meta.id
          }))
        folder_params[:solution_folder_meta].except!(:solution_category_meta_id)
        params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :lang_codes => new_ver_lang + [:primary],
          :folder_id => @folder_meta.id
          }))
        params[:solution_article_meta].merge!(folder_params)
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        solution_check_updates(new_ver_lang, article_meta, params, :article)
        solution_check_updates(new_ver_lang, article_meta.solution_folder_meta, folder_params, :folder)
      end

      it "should be created with brand new folder" do
        new_ver_lang = @remaining_langs.sample(2) + [:primary]
        folder_params = create_solution_folder_alone(solution_default_params(:folder).merge({
          :lang_codes => new_ver_lang,
          :category_id => @category_meta.id
          }))
        params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :lang_codes => new_ver_lang
          }))
        params[:solution_article_meta].merge!(folder_params)
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        solution_check_updates(new_ver_lang, article_meta, params, :article)
        solution_check_updates(new_ver_lang, article_meta.solution_folder_meta, folder_params, :folder)
      end

      it "should be created with folder & category versions" do
        new_ver_lang = @remaining_langs.sample(2)
        category_params = create_solution_category_alone(solution_default_params(:category).merge({
          :lang_codes => new_ver_lang,
          :id => @category_meta.id 
        }))
        folder_params = create_solution_folder_alone(solution_default_params(:folder).merge({
          :lang_codes => new_ver_lang,
          :id => @folder_meta.id,
          :category_id => @category_meta.id
          }))
        folder_params[:solution_folder_meta].merge!(category_params)
        folder_params[:solution_folder_meta].except!(:solution_category_meta_id)
        params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :lang_codes => new_ver_lang + [:primary],
          :folder_id => @folder_meta.id
          }))
        params[:solution_article_meta].merge!(folder_params)
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        solution_check_updates(new_ver_lang, article_meta, params, :article)
        solution_check_updates(new_ver_lang, article_meta.solution_folder_meta, folder_params, :folder)
        solution_check_updates(new_ver_lang, article_meta.solution_folder_meta.solution_category_meta, category_params, :category)
      end

      it "should be created with brand new folder & category" do
        new_ver_lang = @remaining_langs.sample(2) + [:primary]
        category_params = create_solution_category_alone(solution_default_params(:category).merge({
          :lang_codes => new_ver_lang
        }))
        folder_params = create_solution_folder_alone(solution_default_params(:folder).merge({
          :lang_codes => new_ver_lang
          }))
        folder_params[:solution_folder_meta].merge!(category_params)
        params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :lang_codes => new_ver_lang
          }))
        params[:solution_article_meta].merge!(folder_params)
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        solution_check_updates(new_ver_lang, article_meta, params, :article)
        solution_check_updates(new_ver_lang, article_meta.solution_folder_meta, folder_params, :folder)
        solution_check_updates(new_ver_lang, article_meta.solution_folder_meta.solution_category_meta, category_params, :category)
        article_meta.solution_folder_meta.solution_category_meta.destroy
      end

      after(:example) do
        @category_meta.destroy
      end

    end

  end

  describe "Using old param structure" do

    describe "category" do

      it "should be created" do
        c_params = solution_api_category
        category_meta = Solution::Builder.category(c_params)
        expect(category_meta.id).to be_present
        expect(category_meta.primary_category).to be_present
        expect(category_meta.primary_category.name).to be_eql(c_params[:solution_category][:name])
        expect(category_meta.is_default).to be_eql(false)
        category_meta.destroy
      end

      it "should be updated" do
        category_meta = Solution::Builder.category(solution_api_category)
        expect(category_meta.id).to be_present
        params = solution_api_category({:name => "New name #{Faker::Name.name}"})
        params[:solution_category].merge!({:id => category_meta.id})
        category_meta = Solution::Builder.category(params)
        expect(category_meta.primary_category.name).to be_eql(params[:solution_category][:name])
        expect(category_meta.portal_ids).to include(@account.main_portal.id)
        category_meta.destroy
      end

    end

    describe "folder" do
      
      before(:example) do
        @category_meta = Solution::Builder.category(solution_api_category)
        @category_meta2 = Solution::Builder.category(solution_api_category)
      end

      it "should be created" do
        params = solution_api_folder
        params[:solution_folder].merge!(:category_id => @category_meta.id)
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.id).to be_present
        expect(folder_meta.primary_folder).to be_present
      end

      it "should be updated" do
        params = solution_api_folder
        params[:solution_folder].merge!(:category_id => @category_meta.id)
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.id).to be_present
        initial_meta_id = folder_meta.id
        params = solution_api_folder({:name => "New name #{Faker::Name.name}"})
        params[:solution_folder].merge!({:category_id => @category_meta2.id, :id => folder_meta.id})
        folder_meta = Solution::Builder.folder(params)
        expect(folder_meta.primary_folder).to be_present
        expect(folder_meta.primary_folder.name).to be_eql(params[:solution_folder][:name])
        expect(folder_meta.solution_category_meta_id).to be_eql(@category_meta2.id)
        expect(folder_meta.id).to be_eql(initial_meta_id)
      end

      it "should be updated with new visibility (company)" do
        params = solution_api_folder
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

        params = solution_api_folder({:name => "New name #{Faker::Name.name}"})
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

      after(:example) do
        @category_meta.destroy
        @category_meta2.destroy
      end

    end

    describe "article" do
      
      before(:example) do
        @category_meta = Solution::Builder.category(solution_api_category)
        params = solution_api_folder
        params[:solution_folder].merge!(:category_id => @category_meta.id)
        @folder_meta = Solution::Builder.folder(params)
        params = solution_api_folder
        params[:solution_folder].merge!(:category_id => @category_meta.id)
        @folder_meta2 = Solution::Builder.folder(params)
      end
      
      it "should create" do
        params = solution_api_article({:folder_id => @folder_meta.id})
        article_meta = Solution::Builder.article(params)
        expect(article_meta.id).to be_present
        expect(article_meta.primary_article).to be_present
        expect(article_meta.primary_article.title).to be_eql(params[:solution_article][:title])
      end

      it "should update" do
        params = solution_api_article({:folder_id => @folder_meta.id})
        article_meta = Solution::Builder.article(params)
        expect(article_meta.solution_folder_meta_id).to be_eql(@folder_meta.id)
        expect(article_meta.art_type).to be_eql(2)
        expect(article_meta.primary_article.status).to be_eql(1)
        update_params = solution_api_article({
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

      after(:example) do
        @category_meta.destroy
      end

    end

    after(:all) do
      @account.account_additional_settings.supported_languages = @initial_lang_list
      @account.save
    end

  end

  def solution_check_updates(lang_vers, meta_obj, params, type = :category)
    params.deep_symbolize_keys!
    name_type = type == :article ? :title : :name
    lang_vers.each do |lang|
      sol_obj_ver = meta_obj.send("#{lang}_#{type}")
      expect(sol_obj_ver).to be_present
      expect(sol_obj_ver.send("#{name_type}")).to be_eql(params["solution_#{type}_meta".to_sym]["#{lang}_#{type}".to_sym][name_type])
    end
  end

end