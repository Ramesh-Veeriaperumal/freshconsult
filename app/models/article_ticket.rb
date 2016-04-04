class ArticleTicket < ActiveRecord::Base

	belongs_to :article,
		:class_name => 'Solution::Article',
		:foreign_key => 'article_id'

	belongs_to :ticketable, :polymorphic => true
  
	belongs_to_account  
	    	 
	validates_presence_of :article_id, :ticketable_id, :ticketable_type

end
