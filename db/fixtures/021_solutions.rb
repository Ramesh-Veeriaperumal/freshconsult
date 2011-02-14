account = Account.current

folder = Solution::Folder.seed(:account_id, :name) do |s|
  s.account_id = account.id
  s.name = 'General'
  s.description = 'Default solution category, feel free to edit or delete it.'
end

guide = Helpdesk::Guide.seed_many(:account_id, :folder_id, :name, [
  {
    :account_id => account.id,
    :folder_id => folder.id,
    :name => 'FAQ',
    :description => 'Default solution folder, feel free to edit or delete it.'
  },
  
  {
    :account_id => account.id,
    :folder_id => folder.id,
    :name => 'Getting Started',
    :description => 'Default solution folder, feel free to edit or delete it.'
  }
])
