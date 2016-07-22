module SolutionsTestHelper
  def solution_category_pattern(expected_output = {}, ignore_extra_keys = true, category)
    result = {
      id: expected_output[:id] || category.parent.id,
      name: expected_output[:name] || category.name,
      description: expected_output[:description] || category.description,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
    }
    result.merge!(visible_in_portals: category.parent.portal_solution_categories.pluck(:portal_id)) if Account.current.has_multiple_portals?
    result
  end

  def solution_folder_pattern(expected_output = {}, ignore_extra_keys = true, folder)
    result = {
      id: expected_output[:id] || folder.parent.id,
      name: expected_output[:name] || folder.name,
      description: expected_output[:description] || folder.description,
      visibility: expected_output[:visibility] || folder.solution_folder_meta.visibility,
      category_id: expected_output[:category_id] || folder.solution_folder_meta.category_id,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
    }
    result.merge!(company_ids: folder.solution_folder_meta.customer_ids) if folder.parent.visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]
    result
  end

  def solution_folder_pattern_index(expected_output = {}, ignore_extra_keys = true, folder)
    solution_folder_pattern(expected_output = {}, ignore_extra_keys = true, folder).except(:category_id)
  end

  def solution_article_pattern(expected_output = {}, ignore_extra_keys = true, article)

    expected_tags = expected_output[:tags] ? expected_output[:tags].map(&:downcase) : nil

    {
      id: expected_output[:id] || article.parent.id,
      title: expected_output[:title] || article.title,
      description: expected_output[:description] || article.description,
      description_text: expected_output[:description_text] || article.desc_un_html,
      agent_id: expected_output[:agent_id] || article.user_id,
      type: expected_output[:type] || article.parent.reload.art_type,
      category_id: expected_output[:category_id] || article.parent.reload.solution_category_meta.id,
      folder_id: expected_output[:folder_id] || article.parent.reload.solution_folder_meta.id,
      thumbs_up: expected_output[:thumbs_up] || article.solution_article_meta.thumbs_up,
      thumbs_down: expected_output[:thumbs_down] || article.solution_article_meta.thumbs_down,
      hits: expected_output[:hits] || article.solution_article_meta.hits,
      status: expected_output[:status] || article.status,
      tags: expected_tags || article.tags.map{|x| x.name.downcase},
      seo_data: expected_output[:seo_data] || article.seo_data,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
    }
  end

  def solution_article_pattern_index(expected_output = {}, ignore_extra_keys = true, article)
    solution_article_pattern(expected_output = {}, ignore_extra_keys = true, article).except(:tags)
  end

  def v1_category_payload
    { solution_category: { name: "API V1", description: "API V1 Description" } }.to_json
  end

  def v2_category_payload
    { name: "API V2", description: "API V2 Description" }.to_json
  end

  def v1_folder_payload
    { solution_folder: { name: "API V1", description: "API V1 Description", visibility: 1 } }.to_json
  end

  def v2_folder_payload
    { name: "API V2", description: "API V2 Description", visibility: 1 }.to_json
  end

  def v1_article_payload(folder_id)
    { solution_article: { title: "API V1", description: "API V1 Description", status: 1, art_type: 1, folder_id: folder_id } }.to_json
  end

  def v2_article_payload
    { title: "API V1", description: "API V1 Description", status: 1, type: 1 }.to_json
  end

  def v1_article_update_payload
    { solution_article: { description: "API V1 Description" } }.to_json
  end

  def v2_article_update_payload
    { description: "API V1 Description" }.to_json
  end


end
