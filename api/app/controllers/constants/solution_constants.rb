module SolutionConstants
  CATEGORY_FIELDS = %w(description name visible_in).freeze

  CATEGORY_ATTRIBUTES_TO_BE_STRIPPED = %w(name).freeze

  FOLDER_FIELDS = %w(description name visibility company_ids).freeze

  FOLDER_ATTRIBUTES_TO_BE_STRIPPED = %w(name).freeze

  ARTICLE_SEO_DATA_FIELDS = %w(meta_title meta_description meta_keywords)

  CREATE_ARTICLE_FIELDS = %w(category_name folder_name description title status seo_data type tags).freeze | ['seo_data' => ARTICLE_SEO_DATA_FIELDS]
  UPDATE_ARTICLE_FIELDS = %w(agent_id) | CREATE_ARTICLE_FIELDS

  ARTICLE_ATTRIBUTES_TO_BE_STRIPPED = %w(title category_name folder_name).freeze

  TITLE_MAX_LENGTH = 240
  TITLE_MIN_LENGTH = 3

  LOAD_OBJECT_EXCEPT = [:category_folders, :folder_articles].freeze

  ADMIN_TASKS = :admin_tasks
end
