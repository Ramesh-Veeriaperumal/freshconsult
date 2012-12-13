class AddIndexAccountIdAndTicketIdOnTicketTopics < ActiveRecord::Migration
  def self.up
  	execute <<-SQL
  		CREATE INDEX `index_account_id_and_ticket_id_on_ticket_topics` ON ticket_topics (`account_id`,`ticket_id`)
  	SQL
  end

  def self.down
  	execute <<-SQL
  		DROP INDEX `index_account_id_and_ticket_id_on_ticket_topics` ON ticket_topics
  	SQL
  end
end
