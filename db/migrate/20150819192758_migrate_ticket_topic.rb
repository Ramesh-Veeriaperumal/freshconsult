class MigrateTicketTopic < ActiveRecord::Migration
  shard :all
  def up
  	TicketTopics.find_in_batches(:batch_size => 300) do |ticket_topics|
  		ticket_topics.each do |ticket_topic|
        ticket_topic.ticketable_id = ticket_topic.ticket_id
        ticket_topic.ticketable_type = "Helpdesk::Ticket"
        ticket_topic.save
      end
  	end
  end

  def down
  end
end
