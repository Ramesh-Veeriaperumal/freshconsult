class ArticleTicket < ActiveRecord::Base

  belongs_to :article, class_name: 'Solution::Article', foreign_key: 'article_id'

  belongs_to :ticketable, polymorphic: true
  
  belongs_to_account

  include Solution::Constants

  concerned_with :presenter
  publishable
  before_destroy :save_deleted_article_ticket_info
  before_save :set_interaction_source
  validates_presence_of :article_id, :ticketable_id, :ticketable_type

  attr_accessor :interaction_source_id, :interaction_source_type

  def save_deleted_article_ticket_info
    @deleted_model_info = as_api_response(:central_publish_destroy)
  end

  def set_interaction_source
    current_portal = Portal.current || Account.current.main_portal
    self.interaction_source_type = INTERACTION_SOURCE[:portal]
    self.interaction_source_id = current_portal.id
  end
end
