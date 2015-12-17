require 'spec_helper'

describe Solution::Draft do
  setup :activate_authlogic
  self.use_transactional_fixtures = false
  
  before(:all) do
    @agent1 = add_test_agent
    @agent2 = add_test_agent
    @test_category = create_category( {:name => "test category #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    @public_folder  = create_folder({
                                      :name => "Public #{Faker::Name.name} visible to All", 
                                      :description => "#{Faker::Lorem.sentence(3)}", 
                                      :visibility => 1,
                                      :category_id => @test_category.id 
                                    })

    @draft_article1 = create_article( {:title => "article1 agent1 #{@agent1.id} #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(1)}", :folder_id => @public_folder.id, 
      :status => "1", :art_type => "1", :user_id => "#{@agent1.id}" } )

    @draft_article2 = create_article( {:title => "article2 agent2[#{@agent2.id}] #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @public_folder.id, 
      :status => "1", :art_type => "1", :user_id => "#{@agent2.id}" } )
    @agent1.make_current
  end

  before(:each) do
    @draft_article3 = create_article( {:title => "article3 agent1[#{@agent1.id}] #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(2)}", :folder_id => @public_folder.id, 
        :status => "1", :art_type => "1", :user_id => "#{@agent1.id}" } )
    @draft_article3.create_draft_from_article({:title => "Draft 1 for publish #{Faker::Name.name}", :description => "Desc 1 : #{Faker::Lorem.sentence(4)}"})
    @draft = @draft_article3.draft
  end
  
  describe "locked? method" do
    
    #article not locked at all
    it "should return false when article not locked at all" do
      @draft.locked?.should be_eql(false)
    end

    #Some other agent is editing the article
    it "should return true when Some other agent is editing the article" do
      @agent2.make_current
      @draft.status = Solution::Draft::STATUS_KEYS_BY_TOKEN[:editing]
      @draft.save
      @agent1.make_current
      @draft.reload
      @draft.locked?.should be_eql(true)
    end

    #Same user is editing the article
    it "should return false when Same user is editing the article" do
      @draft.user_id = @agent1.id
      @draft.status = Solution::Draft::STATUS_KEYS_BY_TOKEN[:editing]
      @draft.save
      @draft.reload
      @draft.locked?.should be_eql(false)
    end

  end

  describe "lock_for_editing! method" do
    it "should return true when locking an unlocked article" do
      @draft.lock_for_editing!.should be_eql(true)
    end

    it "should return false when locking an already locked article" do
      @agent2.make_current
      @draft.status = Solution::Draft::STATUS_KEYS_BY_TOKEN[:editing]
      @draft.save
      @agent1.make_current
      @draft.reload
      @draft.lock_for_editing!.should be_eql(false)
    end
  end

  describe "unlock method" do
    it "should unlock a draft" do
      @draft.unlock
      @draft.save
      @draft.reload
      @draft.locked?.should be_eql(false)
    end
  end

  describe "publish! method" do
    it "should publish the article draft" do
      title = @draft.title
      @draft.publish!
      @draft_article3.reload
      @draft_article3.title.should be_eql(title)
      @draft_article3.draft.should be_nil
    end
  end

  describe "updation_timestamp method" do
    it "should give that updated timestamp" do
      @draft.updation_timestamp.should be_eql(@draft.updated_at.to_i)
    end

    it "should give the last updated timestamp" do
      timestamp = @draft.updation_timestamp
      sleep(2)
      @draft.update_attributes(:description => "Updated content")
      @draft.updation_timestamp.should be_eql(@draft.draft_body.updated_at.to_i)
      @draft.updation_timestamp.should_not be_eql(timestamp.to_i)
    end
  end

  describe "deleted_attachments method" do
    before(:each) do
      @attachment = @draft_article3.attachments.build(:content => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary), 
                                          :description => Faker::Name.first_name, 
                                          :account_id => @draft_article3.account_id)
      @attachment.save
      @draft.meta[:deleted_attachments] = {:attachments => [@attachment.id] }
    end

    it "should give the deleted attachments IDs" do
      del_atts = [@attachment.id]
      @draft.deleted_attachments(:attachments).should be_eql(del_atts)
    end
  end

  describe "Activities for Solution Drafts" do

    before(:each) do
      @article_published = create_article( {:title => "article2 agent2[#{@agent2.id}] #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @public_folder.id, :status => "2", :art_type => "1", :user_id => "#{@agent2.id}" } )
      @article_published.create_draft_from_article({:title => "Draft for publish #{Faker::Name.name}", :description => "Desc 1 : #{Faker::Lorem.sentence(4)}"})
      @draft = @article_published.draft
    end

    it "should create activity when article-draft is created" do
      @draft.activities.last.description.should eql 'activities.solutions.new_draft.long'
      @draft.activities.last.updated_at.to_date.should eql Time.now.to_date
    end

    it "should create activity when an article-draft is published" do
      @draft.publish!
      @article_published.reload
      @draft.activities.last.description.should eql 'activities.solutions.published_draft.long'
      @draft.activities.last.updated_at.to_date.should eql Time.now.to_date
    end

    it "should create activity when an article-draft is deleted" do
      @draft.discarding = true
      @draft.destroy
      @draft.activities.last.description.should eql 'activities.solutions.delete_draft.long'
      @draft.activities.last.updated_at.to_date.should eql Time.now.to_date
    end

    it "should not create a delete_draft activity when an article-draft is published" do
      @draft.publish!
      @article_published.reload
      @draft.activities.select{|a| a["description"] == 'activities.solutions.delete_draft.long'}.should eql []
    end

    it "should not create delete_draft activity when an article with an article-draft is deleted" do
      @article_published.destroy
      @draft.activities.select{|a| a["description"] == 'activities.solutions.delete_draft.long'}.should eql []
    end

    it "should create an activity with correct agent" do
      @agent2.make_current
      @draft.discarding = true
      @draft.destroy
      @draft.activities.last.user_id.should eql @agent2.id
    end

    it "should create activity of Solution::Draft notable type" do
      @draft.discarding = true
      @draft.destroy
      @draft.activities.last.notable_type.should eql 'Solution::Draft'
    end

    it "should create activity with the correct path in activity data" do
      @draft.discarding = true
      @draft.destroy
      @draft.activities.last.activity_data[:path].should eql Rails.application.routes.url_helpers.solution_article_path(@draft)
    end
    
    it "should create activity with the correct title in activity data" do
      @draft.discarding = true
      @draft.destroy
      @draft.activities.last.activity_data[:title].should eql @draft.article.title.to_s
    end

    it "should create activity with the correct description" do
      @draft.activities.last.description.should eql 'activities.solutions.new_draft.long'
      @draft.discarding = true
      @draft.destroy
      @draft.activities.last.description.should eql 'activities.solutions.delete_draft.long'
    end

    it "should create activity with the correct short description" do
      @draft.activities.last.short_descr.should eql 'activities.solutions.new_draft.short'
      @draft.discarding = true
      @draft.destroy
      @draft.activities.last.short_descr.should eql 'activities.solutions.delete_draft.short'
    end

    it "should create only one activity for each action" do
      @draft.activities.size.should eql 1
      @draft.discarding = true
      @draft.destroy
      @draft.activities.size.should eql 2
    end
  end
end
