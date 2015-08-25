  account = Account.current


  default_category_meta = Solution::CategoryMeta.seed(:account_id, :is_default) do |category|
    category.account_id = account.id
    category.is_default = true
  end

  default_category = Solution::Category.seed(:account_id) do |category|
    category.account_id = account.id
    category.name = I18n.t('default_category')
    category.parent_id = default_category_meta.id
    category.language_id = Language.for_current_account.id
  end

  category_meta = Solution::CategoryMeta.seed(:account_id, :is_default) do |s|
    s.account_id = account.id
  end

  category = Solution::Category.seed(:account_id, :name) do |s|
    s.account_id = account.id
    s.name = 'General'
    s.description = 'Default solution category, feel free to edit or delete it.'
    s.parent_id = category_meta.id
    s.language_id = Language.for_current_account.id
  end

  folder_metas = Solution::FolderMeta.seed_many([
      [:anyone],
      [:anyone],
      [:agents, :default]
    ].map do |f|
      {
        :account_id => account.id,
        :solution_category_meta_id => (f[1] == :default) ? default_category_meta.id : category_meta.id,
        :visibility => Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[f[0]],
        :is_default => (f[1] == :default)
      }
    end
  )

  folder_metas = Solution::FolderMeta.all

  Solution::Folder.seed_many(:parent_id, :name, [
      ["FAQ", folder_metas[0]],
      ["Getting Started", folder_metas[1]],
      [I18n.t('default_folder'), folder_metas[2]]
    ].map do |f|
      {
        :account_id => account.id,
        :parent_id => f[1].id,
        :name => f[0],
        :language_id => Language.for_current_account.id,
        :description => f[1].is_default? ? '' : 'Default solution folder, feel free to edit or delete it.'
      }
    end
  )
