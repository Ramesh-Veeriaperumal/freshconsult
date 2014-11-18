class ArticleTicket < ActiveRecord::Base

	belongs_to :article,
		:class_name => 'Solution::Article',
		:foreign_key => 'article_id'

	belongs_to :ticket, 
		:class_name => 'Helpdesk::Ticket',
		:foreign_key => 'ticket_id'
  
	belongs_to_account  
	    	 
	validates_presence_of :article_id, :ticket_id, :account_id

	before_create :set_account_id

	private
		def set_account_id
			self.account_id = ticket.account_id
		end

end
