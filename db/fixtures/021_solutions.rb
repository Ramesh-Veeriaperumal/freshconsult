account = Account.current

default_category = Solution::Category.seed(:account_id, :is_default) do |category|
  category.account_id = account.id
  category.name = I18n.t('default_category')
  category.description = I18n.t('default_category_description', :full_domain => account.kbase_email)
  category.is_default = true
end

category = Solution::Category.seed(:account_id, :name) do |s|
  s.account_id = account.id
  s.name = 'General'
  s.description = 'Default solution category, feel free to edit or delete it.'
end

Solution::Folder.seed_many(:category_id, :name, [
    ["FAQ", :anyone],
    ["Getting Started", :anyone],
    [I18n.t('default_folder'), :agents, :default, I18n.t('default_folder_description', :full_domain => account.kbase_email)]
  ].map do |f|
    {
      :account_id => account.id,
      :category_id => (f[2] == :default) ? default_category.id : category.id,
      :name => f[0],
      :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[f[1]],
      :description => f[3] || 'Default solution folder, feel free to edit or delete it.',
      :is_default => (f[2] == :default)
    }
  end
)