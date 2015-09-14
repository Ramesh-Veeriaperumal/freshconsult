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
      @draft.user_id = @agent2.id
      @draft.status = Solution::Draft::STATUS_KEYS_BY_TOKEN[:editing]
      @draft.save
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
      @draft.user_id = @agent2.id
      @draft.status = Solution::Draft::STATUS_KEYS_BY_TOKEN[:editing]
      @draft.save
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

end
