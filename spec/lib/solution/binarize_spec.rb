#------------ Category ---------------

RSpec.describe Solution::CategoryMeta do
  before(:all) do
  	@lang_list = Language.all.map(&:to_key).sample(25) - [@account.language]
  end

  it "should update the availability column based on its versions" do
  	lang_vers = @lang_list.sample(5) + [:primary]
  	remaining_lang = @lang_list - lang_vers
    params = create_solution_category_alone(solution_default_params(:category).merge({
      :lang_codes => lang_vers
      }))
    category_meta = Solution::Builder.category(params)
    lang_vers.each do |lan|
    	expect(category_meta.send("#{lan}_availability")).to be_true
    end
    remaining_lang.each do |lan|
    	expect(category_meta.send("#{lan}_availability")).to be_false
    end
  end

  it "should update the availability column accordingly when its version is deleted" do
  	lang_vers = @lang_list.sample(5) + [:primary]
  	remaining_lang = @lang_list - lang_vers
    params = create_solution_category_alone(solution_default_params(:category).merge({
      :lang_codes => lang_vers
      }))
    category_meta = Solution::Builder.category(params)
    lang_vers.each do |lan|
    	expect(category_meta.send("#{lan}_availability")).to be_true
    end
    lang_vers[0..2].each do |lan|
    	category_meta.send("#{lan}_category").destroy
    	expect(category_meta.send("#{lan}_availability")).to be_false
    end
  end

end

#------------ Folder ---------------

RSpec.describe Solution::FolderMeta do
  before(:all) do
  	@lang_list = Language.all.map(&:to_key).sample(25) - [@account.language]
  	@folder_lang_ver = @lang_list.sample(10)
    params = create_solution_category_alone(solution_default_params(:category).merge({
      :lang_codes => @folder_lang_ver + [:primary]
      }))
    @category_meta = Solution::Builder.category(params)
  end

  it "should update the availability column based on its versions" do
  	lang_vers = @folder_lang_ver.sample(5) + [:primary]
  	remaining_lang = @folder_lang_ver - lang_vers
    params = create_solution_folder_alone(solution_default_params(:folder).merge(
          {   
            :category_id => @category_meta.id,
            :visibility => 2,
            :lang_codes => @folder_lang_ver + [:primary]
          }))
    folder_meta = Solution::Builder.folder(params)
    lang_vers.each do |lan|
    	expect(folder_meta.send("#{lan}_availability")).to be_true
    end
    remaining_lang.each do |lan|
    	expect(folder_meta.send("#{lan}_availability")).to be_false
    end
  end

  it "should update the availability column accordingly when its version is deleted" do
  	lang_vers = @folder_lang_ver.sample(5) + [:primary]
  	remaining_lang = @folder_lang_ver - lang_vers
    params = create_solution_folder_alone(solution_default_params(:folder).merge(
          {   
            :category_id => @category_meta.id,
            :visibility => 2,
            :lang_codes => @folder_lang_ver + [:primary]
          }))
    folder_meta = Solution::Builder.folder(params)
    lang_vers.each do |lan|
    	expect(folder_meta.send("#{lan}_availability")).to be_true
    end
    lang_vers[0..2].each do |lan|
    	folder_meta.send("#{lan}_folder").destroy
    	expect(folder_meta.send("#{lan}_availability")).to be_false
    end
  end

end

#------------ Article ---------------

RSpec.describe Solution::ArticleMeta do
  before(:all) do
  	@lang_list = Language.all.map(&:to_key).sample(25) - [@account.language]
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
  end

  # ---- Availability ----

  it "should update the availability column based on its versions" do
  	lang_vers = @article_lang_ver.sample(5) + [:primary]
  	remaining_lang = @article_lang_ver - lang_vers
    params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers + [:primary]
          }))
    article_meta = Solution::Builder.article(params)
    lang_vers.each do |lan|
    	expect(article_meta.send("#{lan}_availability")).to be_true
    end
    remaining_lang.each do |lan|
    	expect(article_meta.send("#{lan}_availability")).to be_false
    end
  end

  it "should update the availability column accordingly when its version is deleted" do
  	lang_vers = @article_lang_ver.sample(5) + [:primary]
  	remaining_lang = @article_lang_ver - lang_vers
    params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers + [:primary]
          }))
    article_meta = Solution::Builder.article(params)
    lang_vers.each do |lan|
    	expect(article_meta.send("#{lan}_availability")).to be_true
    end
    lang_vers[0..2].each do |lan|
    	article_meta.send("#{lan}_article").destroy
    	expect(article_meta.send("#{lan}_availability")).to be_false
    end
  end

  # ---- Outdated ----

  it "should update the outdated column for a version as false on creation" do
  	lang_vers = @article_lang_ver.sample(5) + [:primary]
  	remaining_lang = @article_lang_ver - lang_vers
    params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers + [:primary]
          }))
    article_meta = Solution::Builder.article(params)
    lang_vers.each do |lan|
    	expect(article_meta.send("#{lan}_outdated")).to be_false
    end
  end

  it "should update the outdated column for a version as true when marked as outdated" do
  	lang_vers = @article_lang_ver.sample(5) + [:primary]
  	remaining_lang = @article_lang_ver - lang_vers
    params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers + [:primary]
          }))
    article_meta = Solution::Builder.article(params)
    lang_vers[0..2].each do |lan|
    	article_meta.send("#{lan}_article").update_attribute(:outdated, true)
    	expect(article_meta.send("#{lan}_outdated")).to be_true
    end
  end

  it "should update the outdated column for a version as false when marked as up-to-date" do
  	lang_vers = @article_lang_ver.sample(5) + [:primary]
  	remaining_lang = @article_lang_ver - lang_vers
    params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers + [:primary]
          }))
    article_meta = Solution::Builder.article(params)
    lang_vers[0..2].each do |lan|
    	article_meta.send("#{lan}_article").update_attribute(:outdated, true)
    end
    lang_vers[0..2].each do |lan|
    	article_meta.send("#{lan}_article").update_attribute(:outdated, false)
    	expect(article_meta.send("#{lan}_outdated")).to be_false
    end
  end

  # ---- Published ----

  it "should update the published column for a version as true on creation" do
  	lang_vers = @article_lang_ver.sample(5) + [:primary]
  	remaining_lang = @article_lang_ver - lang_vers
    params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers + [:primary]
          }))
    article_meta = Solution::Builder.article(params)
    lang_vers.each do |lan|
    	expect(article_meta.send("#{lan}_published")).to be_true
    end
  end

  it "should update the published column for a version as false when marked as unpublished" do
  	lang_vers = @article_lang_ver.sample(5) + [:primary]
  	remaining_lang = @article_lang_ver - lang_vers
    params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers + [:primary]
          }))
    article_meta = Solution::Builder.article(params)
    lang_vers[0..2].each do |lan|
    	article_meta.send("#{lan}_article").update_attribute(:status, Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
    	expect(article_meta.send("#{lan}_published")).to be_false
    end
  end

  it "should update the published column for a version as false when marked as published" do
  	lang_vers = @article_lang_ver.sample(5) + [:primary]
  	remaining_lang = @article_lang_ver - lang_vers
    params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers + [:primary]
          }))
    article_meta = Solution::Builder.article(params)
    lang_vers[0..2].each do |lan|
    	article_meta.send("#{lan}_article").update_attribute(:status, Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
    end
    lang_vers[0..2].each do |lan|
    	article_meta.send("#{lan}_article").update_attribute(:status, Solution::Article::STATUS_KEYS_BY_TOKEN[:published])
    	expect(article_meta.send("#{lan}_published")).to be_true
    end
  end

  # ---- Draft ----

  it "should update the draft column for a version as false on creation" do
  	lang_vers = @article_lang_ver.sample(5) + [:primary]
  	remaining_lang = @article_lang_ver - lang_vers
    params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers + [:primary]
          }))
    article_meta = Solution::Builder.article(params)
    lang_vers.each do |lan|
    	expect(article_meta.send("#{lan}_draft")).to be_false
    end
  end

  it "should update the draft column for a version as true when draft is created" do
  	lang_vers = @article_lang_ver.sample(5) + [:primary]
  	remaining_lang = @article_lang_ver - lang_vers
    params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers + [:primary]
          }))
    article_meta = Solution::Builder.article(params)
    lang_vers[0..2].each do |lan|
    	article_meta.send("#{lan}_article").create_draft_from_article
    	expect(article_meta.send("#{lan}_draft")).to be_true
    end
  end

  it "should update the draft column for a version as false when marked draft is discarded" do
  	lang_vers = @article_lang_ver.sample(5) + [:primary]
  	remaining_lang = @article_lang_ver - lang_vers
    params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers + [:primary]
          }))
    article_meta = Solution::Builder.article(params)
    lang_vers[0..2].each do |lan|
    	article_meta.send("#{lan}_article").create_draft_from_article
    end
    lang_vers[0..2].each do |lan|
    	article_meta.send("#{lan}_article").draft.destroy
    	expect(article_meta.send("#{lan}_draft")).to be_false
    end
  end

  it "should update the draft column for a version as false when marked draft is published" do
  	lang_vers = @article_lang_ver.sample(5) + [:primary]
  	remaining_lang = @article_lang_ver - lang_vers
    params = create_solution_article_alone(solution_default_params(:article, :title).merge({
          :folder_id => @folder_meta.id,
          :lang_codes => lang_vers + [:primary]
          }))
    article_meta = Solution::Builder.article(params)
    lang_vers[0..2].each do |lan|
    	article_meta.send("#{lan}_article").create_draft_from_article
    end
    lang_vers[0..2].each do |lan|
    	article_meta.send("#{lan}_article").draft.publish!
    	expect(article_meta.send("#{lan}_draft")).to be_false
    end
  end

end