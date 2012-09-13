include Gamification::Quests::Seed

account = Account.current

Quest.seed_many(:account_id, :badge_id, DEFAULT_DATA.map do |f|
    {
      :account_id => account.id,
      :name => f[:name],
      :description => f[:description], 
      :category => f[:category], 
      :sub_category => f[:sub_category], 
      :active => f[:active], 
      :points => f[:points],
      :badge_id => f[:badge_id],
      :filter_data => f[:filter_data],
      :quest_data => f[:quest_data]
    }
  end
)
