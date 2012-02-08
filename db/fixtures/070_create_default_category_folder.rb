account = Account.current

default_category = Solution::Category.seed(:account_id, :is_default) do |category|
  category.account_id = account.id
  category.name = I18n.t('default_category')
  category.description = I18n.t('default_category_description', :full_domain => "kbase@#{account.full_domain}")
  category.is_default = true
end

default_category.move_to_top

Solution::Folder.seed(:category_id, :is_default) do |folder|
  folder.name = I18n.t('default_folder')
  folder.description = I18n.t('default_folder_description', :full_domain => "kbase@#{account.full_domain}")
  folder.visibility = 3
  folder.is_default = true
  folder.category_id = default_category.id
end

