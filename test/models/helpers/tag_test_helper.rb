module TagTestHelper

  def create_tag(account, options= {})
    unless options[:build_new_tag]
      tag = account.tags.first
      return tag if tag
    end

    test_tag = FactoryGirl.build(:tag,
      :name => options[:name] || Faker::Name.name,
      :tag_uses_count => 1,
      :account_id => account.id
    )
    test_tag.save
    
    test_tag

  end

  def central_publish_tag_pattern(tag)
    {
      id: tag.id,
      name: tag.name,
      account_id: tag.account_id,
      tag_uses_count: tag.tag_uses_count
      
    }
  end

end