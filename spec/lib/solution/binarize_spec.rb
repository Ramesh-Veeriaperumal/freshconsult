#------------ Category ---------------

RSpec.describe Solution::CategoryMeta do
	before(:all) do
		@lang_list = Language.all.map(&:to_key).sample(25) - [@account.language]
	end

	it "should update the available column based on its versions" do
		lang_vers = @lang_list.sample(5)
		remaining_lang = @lang_list - lang_vers
		params = create_solution_category_alone(solution_default_params(:category).merge({
			:lang_codes => lang_vers + [:primary]
		}))
		category_meta = Solution::Builder.category(params)
		category_meta.reload
		lang_vers.each do |lan|
			category_meta.send("#{lan}_available?").should be_truthy
		end
		remaining_lang.each do |lan|
			category_meta.send("#{lan}_available?").should be_falsey
		end
	end

	it "should update the available column accordingly when its version is deleted" do
		lang_vers = @lang_list.sample(5)
		remaining_lang = @lang_list - lang_vers
		params = create_solution_category_alone(solution_default_params(:category).merge({
			:lang_codes => lang_vers + [:primary]
		}))
		category_meta = Solution::Builder.category(params)
		category_meta.reload
		lang_vers.each do |lan|
			category_meta.send("#{lan}_available?").should be_truthy
		end
		lang_vers[0..2].each do |lan|
			category_meta.send("#{lan}_category").destroy
			category_meta.reload
			category_meta.send("#{lan}_available?").should be_falsey
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

	it "should update the available column based on its versions" do
		lang_vers = @folder_lang_ver.sample(5)
		remaining_lang = @folder_lang_ver - lang_vers
		params = create_solution_folder_alone(solution_default_params(:folder).merge(
		{   
			:category_id => @category_meta.id,
			:visibility => 2,
			:lang_codes => lang_vers + [:primary]
		}))
		folder_meta = Solution::Builder.folder(params)
		folder_meta.reload
		lang_vers.each do |lan|
			folder_meta.send("#{lan}_available?").should be_truthy
		end
		remaining_lang.each do |lan|
			folder_meta.send("#{lan}_available?").should be_falsey
		end
	end

	it "should update the available column accordingly when its version is deleted" do
		lang_vers = @folder_lang_ver.sample(5)
		remaining_lang = @folder_lang_ver - lang_vers
		params = create_solution_folder_alone(solution_default_params(:folder).merge(
		{   
			:category_id => @category_meta.id,
			:visibility => 2,
			:lang_codes => lang_vers + [:primary]
		}))
		folder_meta = Solution::Builder.folder(params)
		folder_meta.reload
		lang_vers.each do |lan|
			folder_meta.send("#{lan}_available?").should be_truthy
		end
		lang_vers[0..2].each do |lan|
			folder_meta.send("#{lan}_folder").destroy
			folder_meta.reload
			folder_meta.send("#{lan}_available?").should be_falsey
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

	# ---- available ----

	it "should update the available column based on its versions" do
		lang_vers = @article_lang_ver.sample(5)
		remaining_lang = @article_lang_ver - lang_vers
		params = create_solution_article_alone(solution_default_params(:article, :title).merge({
			:folder_id => @folder_meta.id,
			:lang_codes => lang_vers + [:primary]
		}))
		article_meta = Solution::Builder.article(params)
		article_meta.reload
		lang_vers.each do |lan|
			article_meta.send("#{lan}_available?").should be_truthy
		end
		remaining_lang.each do |lan|
			article_meta.send("#{lan}_available?").should be_falsey
		end
	end

	it "should update the available column accordingly when its version is deleted" do
		lang_vers = @article_lang_ver.sample(5)
		remaining_lang = @article_lang_ver - lang_vers
		params = create_solution_article_alone(solution_default_params(:article, :title).merge({
			:folder_id => @folder_meta.id,
			:lang_codes => lang_vers + [:primary]
		}))
		article_meta = Solution::Builder.article(params)
		article_meta.reload
		lang_vers.each do |lan|
			article_meta.send("#{lan}_available?").should be_truthy
		end
		lang_vers[0..2].each do |lan|
			article_meta.send("#{lan}_article").destroy
			article_meta.reload
			article_meta.send("#{lan}_available?").should be_falsey
		end
	end

	# ---- Outdated ----

	it "should update the outdated column for a version as false on creation" do
		lang_vers = @article_lang_ver.sample(5)
		remaining_lang = @article_lang_ver - lang_vers
		params = create_solution_article_alone(solution_default_params(:article, :title).merge({
			:folder_id => @folder_meta.id,
			:lang_codes => lang_vers + [:primary]
		}))
		article_meta = Solution::Builder.article(params)
		article_meta.reload
		lang_vers.each do |lan|
			article_meta.send("#{lan}_outdated?").should be_falsey
		end
	end

	it "should update the outdated column for a version as true when marked as outdated" do
		lang_vers = @article_lang_ver.sample(5)
		remaining_lang = @article_lang_ver - lang_vers
		params = create_solution_article_alone(solution_default_params(:article, :title).merge({
			:folder_id => @folder_meta.id,
			:lang_codes => lang_vers + [:primary]
		}))
		article_meta = Solution::Builder.article(params)
		article_meta.send("#{lang_vers[0]}_article").update_attributes(:outdated => true)
		article_meta.reload
		article_meta.send("#{lang_vers[0]}_outdated?").should be_truthy
	end

	it "should update the outdated column for a version as false when marked as up-to-date" do
		lang_vers = @article_lang_ver.sample(5)
		remaining_lang = @article_lang_ver - lang_vers
		params = create_solution_article_alone(solution_default_params(:article, :title).merge({
			:folder_id => @folder_meta.id,
			:lang_codes => lang_vers + [:primary],
			:outdated => true
		}))
		article_meta = Solution::Builder.article(params)
		article_meta.reload
		article_meta.send("#{lang_vers[0]}_article").update_attributes(:outdated => false)
		article_meta.reload
		article_meta.send("#{lang_vers[0]}_outdated?").should be_falsey
	end

	# ---- Published ----

	it "should update the published column for a version as true on creation" do
		lang_vers = @article_lang_ver.sample(5)
		remaining_lang = @article_lang_ver - lang_vers
		params = create_solution_article_alone(solution_default_params(:article, :title).merge({
			:folder_id => @folder_meta.id,
			:lang_codes => lang_vers + [:primary],
			:status => Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
		}))
		article_meta = Solution::Builder.article(params)
		article_meta.reload
		lang_vers.each do |lan|
			article_meta.send("#{lan}_published?").should be_truthy
		end
	end

	it "should update the published column for a version as false when marked as unpublished" do
		lang_vers = @article_lang_ver.sample(5)
		remaining_lang = @article_lang_ver - lang_vers
		params = create_solution_article_alone(solution_default_params(:article, :title).merge({
			:folder_id => @folder_meta.id,
			:lang_codes => lang_vers + [:primary]
		}))
		article_meta = Solution::Builder.article(params)
		article_meta.send("#{lang_vers[0]}_article").update_attributes(:status => Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
		article_meta.reload
		article_meta.send("#{lang_vers[0]}_published?").should be_falsey
	end

	it "should update the published column for a version as false when marked as published" do
		lang_vers = @article_lang_ver.sample(5)
		remaining_lang = @article_lang_ver - lang_vers
		params = create_solution_article_alone(solution_default_params(:article, :title).merge({
			:folder_id => @folder_meta.id,
			:lang_codes => lang_vers + [:primary],
			:status => Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
		}))
		article_meta = Solution::Builder.article(params)
		article_meta.reload
		article_meta.send("#{lang_vers[0]}_article").update_attributes(:status => Solution::Article::STATUS_KEYS_BY_TOKEN[:published])
		article_meta.reload
		article_meta.send("#{lang_vers[0]}_published?").should be_truthy
	end

	# ---- Draft ----

	it "should update the draft column for a version as false on creation" do
		lang_vers = @article_lang_ver.sample(5)
		remaining_lang = @article_lang_ver - lang_vers
		params = create_solution_article_alone(solution_default_params(:article, :title).merge({
			:folder_id => @folder_meta.id,
			:lang_codes => lang_vers + [:primary]
		}))
		article_meta = Solution::Builder.article(params)
		article_meta.reload
		lang_vers.each do |lan|
			article_meta.send("#{lan}_draft?").should be_falsey
		end
	end

	it "should update the draft column for a version as true when draft is created" do
		lang_vers = @article_lang_ver.sample(5)
		remaining_lang = @article_lang_ver - lang_vers
		params = create_solution_article_alone(solution_default_params(:article, :title).merge({
			:folder_id => @folder_meta.id,
			:lang_codes => lang_vers + [:primary]
		}))
		article_meta = Solution::Builder.article(params)
		article_meta.send("#{lang_vers[0]}_article").create_draft_from_article
		article_meta.reload
		article_meta.send("#{lang_vers[0]}_draft?").should be_truthy
	end

	it "should update the draft column for a version as false when marked draft is discarded" do
		lang_vers = @article_lang_ver.sample(5)
		remaining_lang = @article_lang_ver - lang_vers
		params = create_solution_article_alone(solution_default_params(:article, :title).merge({
			:folder_id => @folder_meta.id,
			:lang_codes => lang_vers + [:primary]
		}))
		article_meta = Solution::Builder.article(params)
		article_meta.send("#{lang_vers[0]}_article").create_draft_from_article
		article_meta.reload
		article_meta.send("#{lang_vers[0]}_article").draft.destroy
		article_meta.reload
		article_meta.send("#{lang_vers[0]}_draft?").should be_falsey
	end

	it "should update the draft column for a version as false when marked draft is published" do
		lang_vers = @article_lang_ver.sample(5)
		remaining_lang = @article_lang_ver - lang_vers
		params = create_solution_article_alone(solution_default_params(:article, :title).merge({
			:folder_id => @folder_meta.id,
			:lang_codes => lang_vers + [:primary]
		}))
		article_meta = Solution::Builder.article(params)
		article_meta.send("#{lang_vers[0]}_article").create_draft_from_article
		article_meta.reload
		article_meta.send("#{lang_vers[0]}_article").draft.publish!
		article_meta.reload
		article_meta.send("#{lang_vers[0]}_draft?").should be_falsey
	end

end