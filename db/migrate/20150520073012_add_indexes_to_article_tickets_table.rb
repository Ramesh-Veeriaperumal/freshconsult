class AddIndexesToArticleTicketsTable < ActiveRecord::Migration

  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :article_tickets, :atomic_switch => true do |m|
      m.add_unique_index [:account_id, :ticket_id]
    end
  end

  def down
    Lhm.change_table :article_tickets, :atomic_switch => true do |m|
      m.remove_index [:account_id, :ticket_id]
    end
  end

end
