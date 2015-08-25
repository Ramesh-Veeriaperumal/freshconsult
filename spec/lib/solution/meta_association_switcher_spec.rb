require 'spec_helper'

RSpec.describe Solution::MetaAssociationSwitcher do

	before(:all) do
		categories = []
		3.times do
			category = create_category({:is_default => false})
			categories << category
			company_folder = create_folder({:visibility => 4, :category_id => category.id})
			create_customer_folders(company_folder)
			4.times do
				folder = create_folder({:visibility => rand(1..4), :category_id => category.id})
				create_customer_folders(folder) if(folder.has_company_visiblity?)
				8.times do 
					create_article({:folder_id => folder.id, :status => [1,2].sample})
				end
			end
		end
		@mobihelp_app = create_mobihelp_app(:category_ids => categories.map(&:id))
	end

	it "should return the same result both for normal load and load through meta" do
		check_meta_assoc_equality(@account)
		check_meta_assoc_equality(@mobihelp_app)
		check_meta_assoc_equality(@account.main_portal)
		@account.solution_categories.each do |sc|
			check_meta_assoc_equality(sc)
			check_meta_delegates(sc)
			sc.folders.each do |sf|
				check_meta_assoc_equality(sf)
				check_meta_delegates(sf)
				sf.articles.each do |sa|
					check_meta_assoc_equality(sa)
					check_meta_delegates(sa)
				end
			end
		end	
	end

	it "should fetch attributes from meta accordingly for to_indexed_json if meta_read feature is launched" do
		folder = create_folder({:visibility => 1, :category_id => @account.solution_categories.sample.id})
		folder_meta = folder.reload.solution_folder_meta
		article = create_article({:folder_id => folder.id, :status => [1,2].sample})
		article_meta = article.reload.solution_article_meta		
		article_meta.update_attribute(:created_at, Time.now.utc)
		folder_meta.update_attribute(:visibility, 3)
		@account.reload
		@account.rollback(:meta_read)
		indexed_json = JSON.parse(article.to_indexed_json)
		Time.parse(indexed_json["solution/article"]["created_at"]).to_s.should == article.read_attribute(:created_at).to_s
		indexed_json["solution/article"]["folder"]["visibility"].should be_eql(folder.read_attribute(:visibility))	
		@account.launch(:meta_read)
		@account.reload
		@account.make_current
		indexed_json = JSON.parse(Solution::Article.find(article.id).to_indexed_json)	
		Time.parse(indexed_json["solution/article"]["created_at"]).to_s.should == article_meta.read_attribute(:created_at).to_s
		indexed_json["solution/article"]["folder"]["visibility"].should be_eql(folder_meta.read_attribute(:visibility))
		folder_meta.update_attribute(:visibility, folder.read_attribute(:visibility))
	end

	describe "it should return the same result for the altered scopes with/without meta_read feature" do

		it "should return the same results for articles_for_portal scope in Solution::Article model" do
			@account.reload
			@account.launch(:meta_read)
			result1 = @account.solution_articles.articles_for_portal(@account.main_portal)
			@account.rollback(:meta_read)
			result2 = @account.solution_articles.articles_for_portal(@account.main_portal)
			result1.to_a.should == result2.to_a
		end	

		it "should return the same results for visible scope in Solution::Folder model" do
			@account.reload
			user = @account.users.sample
			@account.launch(:meta_read)
			result1 = @account.solution_folders.visible(user)
			@account.rollback(:meta_read)
			result2 = @account.solution_folders.visible(user)
			result1.to_a.should == result2.to_a
		end
	end
end