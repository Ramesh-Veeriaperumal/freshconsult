module SolutionConstants
  CATEGORY_FIELDS = %w(description name visible_in_portals).freeze

  CATEGORY_ATTRIBUTES_TO_BE_STRIPPED = %w(name).freeze

  FOLDER_FIELDS = %w(description name visibility company_ids).freeze

  FOLDER_ATTRIBUTES_TO_BE_STRIPPED = %w(name).freeze

  ARTICLE_SEO_DATA_FIELDS = %w(meta_title meta_description meta_keywords)
  ARTICLE_LANGUAGE_FIELDS = %w(title description status
                              seo_data attachments).map(&:to_sym).freeze

  ARTICLE_ARRAY_FIELDS = %w(tags attachments).freeze
  ARTICLE_FIELDS = %w(category_name folder_name description
                      title status seo_data type).freeze | ARTICLE_ARRAY_FIELDS |
                    ['seo_data' => ARTICLE_SEO_DATA_FIELDS]

  CREATE_ARTICLE_FIELDS = { all: ARTICLE_FIELDS }.freeze
  UPDATE_ARTICLE_FIELDS = { all: ARTICLE_FIELDS, admin_tasks: ['agent_id'] }.freeze

  ARTICLE_ATTRIBUTES_TO_BE_STRIPPED = %w(title category_name folder_name).freeze
  ARTICLE_WRAP_PARAMS = [:article, exclude: [],
                          format: [:json, :multipart_form]].freeze

  ARTICLE_ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:json, :multipart_form],
    update: [:json, :multipart_form]
  }.freeze

  TITLE_MAX_LENGTH = 240
  TITLE_MIN_LENGTH = 3

  LOAD_OBJECT_EXCEPT = [:category_folders, :folder_articles].freeze

  INDEX_FIELDS = %w(language).freeze
end
