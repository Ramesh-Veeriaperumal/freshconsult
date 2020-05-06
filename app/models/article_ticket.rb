class ArticleTicket < ActiveRecord::Base

  belongs_to :article, class_name: 'Solution::Article', foreign_key: 'article_id'

  belongs_to :ticketable, polymorphic: true
  
  belongs_to_account

  concerned_with :presenter
  publishable
  before_destroy :save_deleted_article_ticket_info
  validates_presence_of :article_id, :ticketable_id, :ticketable_type

  def save_deleted_article_ticket_info
    @deleted_model_info = as_api_response(:central_publish_destroy)
  end

end
