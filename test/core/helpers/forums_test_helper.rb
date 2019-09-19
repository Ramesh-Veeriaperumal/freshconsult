module CoreForumsTestHelper

  def create_test_category
    forum_category = FactoryGirl.build(:forum_category, :account_id => @account.id,
                                                    :name => Faker::Lorem.sentence(2))
    forum_category.save(validate: false)
    forum_category
  end

  def create_test_category_with_portals(p1, p2)
    forum_category = FactoryGirl.build(:forum_category, :account_id => @account.id,
                                                    :name => Faker::Lorem.sentence(2),
                                                    :portal_ids => [p1,p2])
    forum_category.save(:validate => false)
    forum_category
  end

  def create_test_forum(forum_category, type = 1, visibility=nil, convert = 0)
    forum = FactoryGirl.build(
              :forum, 
              :account_id => @account.id, 
              :forum_category_id => forum_category.id,
              :forum_type => type,
              :convert_to_ticket => convert
              )
    forum.forum_visibility = visibility if visibility
    forum.save(validate: false)
    forum
  end

  def create_test_topic(forum, user = @customer )
    forum_type_symbol = Forum::TYPE_KEYS_BY_TOKEN[Forum::TYPE_SYMBOL_BY_KEY[forum.forum_type]]
    stamp_type = Topic::ALL_TOKENS_FOR_FILTER[forum_type_symbol].keys[1]
    topic = FactoryGirl.build(
              :topic, 
              :account_id => @account.id, 
              :forum_id => forum.id,
              :user_id => user.id,
              :stamp_type => stamp_type,
              :user_votes => 0
              )
    topic.save!
    post = FactoryGirl.build(:post,
              :account_id => @account.id,
              :topic_id => topic.id,
              :user_id => user.id,
              :forum_id => forum.id,
              :user_votes => 0
              )
    post.save!
    topic.last_post_id = post.id
    publish_post(post)
    topic.reload
  end

  def create_test_topic_with_attachments(forum, user = @customer )
    forum_type_symbol = Forum::TYPE_KEYS_BY_TOKEN[Forum::TYPE_SYMBOL_BY_KEY[forum.forum_type]]
    stamp_type = Topic::ALL_TOKENS_FOR_FILTER[forum_type_symbol].keys[1]
    topic = FactoryGirl.build(
              :topic, 
              :account_id => @account.id, 
              :forum_id => forum.id,
              :user_id => user.id,
              :stamp_type => stamp_type,
              :user_votes => 0
              )
    topic.save
    post = FactoryGirl.build(
              :post,
              :account_id => @account.id,
              :topic_id => topic.id,
              :user_id => user.id,
              :user_votes => 0
              )
    attachment = post.attachments.build(
                  :content => File.new(Rails.root.join("spec/fixtures/files/attachment.txt")), 
                  :description => Faker::Name.first_name, 
                  :account_id => post.account_id)
    attachment.save
    post.save!
    topic.last_post_id = post.id
    publish_post(post)
    topic.reload
  end

  def create_test_topic_with_cloud_files(forum, user = @customer )
    forum_type_symbol = Forum::TYPE_KEYS_BY_TOKEN[Forum::TYPE_SYMBOL_BY_KEY[forum.forum_type]]
    stamp_type = Topic::ALL_TOKENS_FOR_FILTER[forum_type_symbol].keys[1]
    topic = FactoryGirl.build(
              :topic, 
              :account_id => @account.id, 
              :forum_id => forum.id,
              :user_id => user.id,
              :stamp_type => stamp_type,
              :user_votes => 0
              )
    topic.save
    post = FactoryGirl.build(
              :post,
              :account_id => @account.id,
              :topic_id => topic.id,
              :user_id => user.id,
              :user_votes => 0
              )
    cloud_file = post.cloud_files.build(:url => "https://www.dropbox.com/s/7d3z51nidxe358m/Getting Started.pdf?dl=0", 
      :application_id => 20, :filename => "Getting Started.pdf")
    cloud_file.save
    post.save!
    topic.last_post_id = post.id
    publish_post(post)
    topic.reload
  end

  def create_test_post(topic, published = false, user = @customer)
    post = FactoryGirl.build(:post, 
              :account_id => @account.id, 
              :topic_id => topic.id,
              :user_id => user.id,
              :user_votes => 0,
              :published => published
              )
    post.save
    post      
  end

  def publish_post(post)
    post.approve!
    post
  end
end
