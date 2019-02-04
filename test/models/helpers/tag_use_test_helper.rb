module TagUseTestHelper

  def create_tag_use(account, options= {})

    tag_use = account.tag_uses.first
    return tag_use if tag_use

    test_tag = FactoryGirl.build(:tag,
      :name => options[:name] || Faker::Name.name,
      :tag_uses_count => 1,
      :account_id => account.id
    )

    test_tag.save

    test_tag_use = FactoryGirl.build(:tag_use, 
      :tag_id => test_tag.id,
      :taggable_type => 'Helpdesk::Ticket', 
      :taggable_id => account.tickets.first.id,
      :account_id => account.id
      )
    test_tag_use.save(validate: false)
    
    test_tag_use

  end

  def central_publish_tag_use_pattern(tag_use)
    {
    	:id => tag_use.id,
      :tag_id => tag_use.tag_id,
      :taggable_type => tag_use.taggable_type, 
      :taggable_id => tag_use.taggable_id,
      :account_id => tag_use.account_id
    }
  end

end
