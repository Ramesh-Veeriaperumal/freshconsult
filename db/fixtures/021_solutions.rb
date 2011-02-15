account = Account.current

category = Solution::Category.seed(:account_id, :name) do |s|
  s.account_id = account.id
  s.name = 'General'
  s.description = 'Default solution category, feel free to edit or delete it.'
end

Solution::Folder.seed_many(:category_id, :name, [
  {
    :category_id => category.id,
    :name => 'FAQ',
    :description => 'Default solution folder, feel free to edit or delete it.'
  },
  
  {
    :category_id => category.id,
    :name => 'Getting Started',
    :description => 'Default solution folder, feel free to edit or delete it.'
  }
])
