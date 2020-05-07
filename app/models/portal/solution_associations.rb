class Portal < ActiveRecord::Base
  has_many :portal_solution_categories,
           class_name: 'PortalSolutionCategory',
           foreign_key: :portal_id,
           order: 'position',
           inverse_of: :portal,
           dependent: :destroy

  has_many :solution_category_meta,
           class_name: 'Solution::CategoryMeta',
           through: :portal_solution_categories,
           order: 'portal_solution_categories.position',
           after_add: :clear_solution_cache,
           after_remove: :clear_solution_cache

  has_many :public_category_meta,
           class_name: 'Solution::CategoryMeta',
           conditions: { is_default: false },
           through: :portal_solution_categories,
           source: :solution_category_meta

  has_many :bot_folder_meta,
           class_name: 'Solution::FolderMeta',
           conditions: ['`solution_folder_meta`.visibility IN (?)', Solution::Constants::BOT_VISIBILITIES],
           foreign_key: :solution_category_meta_id,
           through: :public_category_meta,
           source: :solution_folder_meta

  has_many :solution_categories,
           class_name: 'Solution::Category',
           through: :public_category_meta,
           order: 'portal_solution_categories.position'

  has_many :bot_article_meta,
           class_name: 'Solution::ArticleMeta',
           through: :bot_folder_meta,
           source: :published_article_meta
end
