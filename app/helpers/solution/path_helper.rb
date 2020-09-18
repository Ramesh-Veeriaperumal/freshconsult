module Solution::PathHelper

  def multilingual_article_path(article, options = {})
    current_account.multilingual? ?
    solution_article_version_path(article, options.slice(:anchor).merge(language: article.language.code)) :
    solution_article_path(article, options.slice(:anchor))
  end

  def agent_actions_path(solution_object = nil, options = {})
    mint_solutions_path(solution_object, options[:anchor] == 'edit')
  end

  def mint_solutions_path(solution_object, edit = false)
    path = '/a/solutions'
    # solution_object won't be present for home path
    path += mint_solution_object_path(solution_object) if solution_object
    path += '/edit' if edit
    if current_account.multilingual? && current_account.products.present?
      path += "?#{append_language}&#{append_portal}"
    else
      path += "?#{append_language}" if current_account.multilingual?
      path += "?#{append_portal}" if current_account.products.present?
    end
    path
  end

  def mint_solution_object_path(solution_object)
    case solution_object.class.name
    when 'Solution::CategoryMeta'
      "/categories/#{solution_object.id}"
    when 'Solution::FolderMeta'
      "/categories/#{solution_object.solution_category_meta_id}/folders/#{solution_object.id}"
    when 'Solution::ArticleMeta'
      "/articles/#{solution_object.parent_id}"
    end
  end

  def old_solutions_path(solution_object, options = {})
    # solution_object won't be present for home path
    return solution_categories_path unless solution_object

    case solution_object.class.name
    when 'Solution::CategoryMeta'
      solution_category_path(solution_object)
    when 'Solution::FolderMeta'
      solution_folder_path(solution_object)
    when 'Solution::ArticleMeta'
      multilingual_article_path(solution_object, options)
    end
  end

  def append_language
    "lang=#{Language.current.code}"
  end

  def append_portal
    "portalId=#{current_portal.id}"
  end
end
