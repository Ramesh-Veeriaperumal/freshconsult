module SolutionFoldersTestHelper
  def create_company
    company = Company.create(name: Faker::Name.name, account_id: @account.id)
    company.save
    company
  end

  def get_company
    company ||= create_company
  end

  def wrap_cname(params)
    { folder: params }
  end

  def meta_scoper
    @account.solution_folder_meta.where(is_default: false)
  end

  def get_folder
    meta_scoper.collect(&:children).flatten.first
  end

  def get_category
    @account.solution_category_meta.where(is_default: false).first
  end

  def get_category_meta_with_translation(language)
    category_meta = @account.solution_category_meta.where(is_default: false).select { |x| x.children if x.children.count > 1 }.first
    category_meta ||= get_category

    language_key = Language.find_by_code(language).to_key
    category_meta.safe_send("create_#{language_key}_category", name: 'Sample Category') unless category_meta.safe_send("#{language_key}_category")
    category_meta
  end

  def get_category_with_folders
    @account.solution_category_meta.where(is_default: false).select { |x| x if x.solution_folder_meta.count > 0 }.first
  end

  def get_category_folders
    @account.solution_category_meta.where(is_default: false).select { |x| x if x.children.count > 0 }
  end

  def get_folder_without_translation_with_translated_category(language)
    category_meta = get_category_meta_with_translation(language)
    folder_meta = category_meta.solution_folder_meta.first || create_folder_meta(category_meta, 1)
    folder_meta = delete_folder_translation(folder_meta, language)
    folder_meta.solution_folders.first || create_folder_translation(Account.current.language_object.to_key, folder_meta)
  end

  def create_folder_meta(category_meta, visibility)
    folder_meta = Solution::FolderMeta.new
    folder_meta.account = @account
    folder_meta.visibility = visibility
    folder_meta.solution_category_meta = category_meta
    folder_meta.save!
    folder_meta
  end

  def delete_folder_translation(folder_meta, language)
    language_key = Language.find_by_code(language).to_key
    if folder_meta.safe_send("#{language_key}_folder")
      folder_meta.safe_send("#{language_key}_folder").destroy
      folder_meta.reload
    end

    folder_meta
  end

  def get_folder_without_translation_without_translated_category
    meta_scoper.select { |x| x.children if x.children.count == 1 }.first
  end

  def get_folder_with_translation
    meta_scoper.select { |x| x.children if x.children.count > 1 }.first
  end

  def get_default_folder
    @account.solution_folder_meta.where(is_default: true).first.children.first
  end

  def get_folders_by_portal_id(portal_id, language = Account.current.language_object)
    @account.solution_folders.joins(solution_folder_meta: [solution_category_meta: :portal_solution_categories]).where("solution_folders.language_id = #{language.id} AND solution_category_meta.is_default = false AND  portal_solution_categories.portal_id = #{portal_id}")
  end

  def create_folder_translation(language, folder_meta = meta_scoper.first)
    folder_meta.safe_send("create_#{language}_folder", name: 'Sample Folder') unless folder_meta.safe_send("#{language}_folder")
  end
end
