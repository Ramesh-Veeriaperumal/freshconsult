['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

module ModelsSolutionsTestHelper
  include SolutionsHelper
  include SolutionBuilderHelper

  def create_portal(params = {})
    test_portal = FactoryGirl.build(:portal,
      name: params[:portal_name] || Faker::Name.name,
      portal_url: params[:portal_url] || '',
      language: 'en',
      forum_category_ids: (params[:forum_category_ids] || ['']),
      solution_category_metum_ids: (params[:solution_category_metum_ids] || params[:solution_category_ids] || ['']),
      account_id: @account.id,
      preferences: {
        logo_link: '',
        contact_info: '',
        header_color: '#252525',
        tab_color: '#006063',
        bg_color: '#efefef'
      })
    test_portal.save(validate: false)
    test_portal
  end

  def add_new_category
    portal = create_portal
    create_category({
      name: "#{Faker::Lorem.sentence(3)}",
      description: "#{Faker::Lorem.sentence(3)}",
      is_default: false,
      portal_ids: [portal.id]
    }).primary_category
  end

  def add_new_folder
    category = add_new_category
    create_folder({
      name: "#{Faker::Lorem.sentence(3)}",
      description: "#{Faker::Lorem.sentence(3)}",
      visibility: 1,
      category_id: category.id
    }).primary_folder
  end

  def add_new_article
    folder = add_new_folder
    create_article({
      title: "#{Faker::Lorem.sentence(3)}",
      description: "#{Faker::Lorem.sentence(3)}",
      folder_id: folder.id,
      user_id: @agent.id,
      status: '2',
      art_type: '1'
    }).primary_article
  end

  def central_publish_category_pattern(category)
    {
      id: category.parent_id,
      name: category.name,
      description: category.description,
      portal_ids: category.parent.portal_ids,
      language_id: category.language_id,
      account_id: category.account_id,
      created_at: category.created_at.try(:utc).try(:iso8601),
      updated_at: category.updated_at.try(:utc).try(:iso8601)
    }
  end

  def central_publish_folder_pattern(folder)
    parent = folder.parent
    {
      id: folder.parent_id,
      name: folder.name,
      description: folder.description,
      visibility: parent.visibility,
      category_id: parent.solution_category_meta_id,
      language_id: folder.language_id,
      account_id: folder.account_id,
      created_at: folder.created_at.try(:utc).try(:iso8601),
      updated_at: folder.updated_at.try(:utc).try(:iso8601)
    }
  end

  def central_publish_article_pattern(article)
    parent = article.parent
    {
      id: article.parent_id,
      title: article.title,
      description: article.description,
      description_text: article.desc_un_html,
      status: article.status,
      agent_id: article.user_id,
      type: parent.art_type,
      category_id: parent.solution_category_meta.id,
      folder_id: parent.solution_folder_meta_id,
      thumbs_up: parent.thumbs_up,
      thumbs_down: parent.thumbs_down,
      hits: parent.hits,
      tags: article.tags,
      seo_data: article.seo_data,
      language_id: article.language_id,
      account_id: article.account_id,
      created_at: article.created_at.try(:utc).try(:iso8601),
      updated_at: article.updated_at.try(:utc).try(:iso8601)
    }
  end

  def central_publish_article_votes_pattern(article)
    parent = article.parent
    {
      id: article.parent_id,
      thumbs_up: parent.thumbs_up,
      thumbs_down: parent.thumbs_down,
      account_id: article.account_id,
      created_at: article.created_at.try(:utc).try(:iso8601),
      updated_at: article.updated_at.try(:utc).try(:iso8601)
    }
  end
end
