class MigrateArticleTickets < ActiveRecord::Migration
  shard :all
  def up
  	ArticleTicket.find_in_batches(:batch_size => 300) do |article_tickets|
      article_tickets.each do |article_ticket|
        article_ticket.ticketable_id = article_ticket.ticket_id
        article_ticket.ticketable_type = "Helpdesk::Ticket"
        article_ticket.save
      end
    end
  end

  def down
  end
end
