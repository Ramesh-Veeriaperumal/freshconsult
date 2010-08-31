class Helpdesk::ArticleGuide < ActiveRecord::Base
  set_table_name "helpdesk_article_guides"

  belongs_to :articles, 
    :class_name => 'Helpdesk::Article',
    :foreign_key => 'article_id'

  belongs_to :guides, 
    :class_name => 'Helpdesk::Guide',
    :foreign_key => 'guide_id',
    :counter_cache => true

  validates_uniqueness_of :article_id, :scope => :guide_id

end
