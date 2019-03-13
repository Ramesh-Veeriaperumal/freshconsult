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

  def get_category_with_folders
    @account.solution_category_meta.where(is_default: false).select { |x| x if x.solution_folder_meta.count > 0 }.first
  end

  def get_category_folders
    @account.solution_category_meta.where(is_default: false).select { |x| x if x.children.count > 0 }
  end

  def get_folder_without_translation
    meta_scoper.select { |x| x.children if x.children.count == 1 }.first
  end

  def get_folder_with_translation
    meta_scoper.select { |x| x.children if x.children.count > 1 }.first
  end

  def get_default_folder
    @account.solution_folder_meta.where(is_default: true).first.children.first
  end
end
