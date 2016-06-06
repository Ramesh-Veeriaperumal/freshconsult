class ChangeIndexOfArchive < ActiveRecord::Migration
  shard :all
  def up
  	Lhm.change_table :archive_notes, :atomic_switch => true do |m|
  	  m.ddl("ALTER TABLE %s ADD COLUMN deleted tinyint(1) DEFAULT '0' " % m.name)
      m.ddl("ALTER TABLE %s DROP PRIMARY KEY" % m.name)
      m.ddl("ALTER TABLE %s ADD PRIMARY KEY(id,account_id)" % m.name)
      m.ddl("ALTER TABLE %s DROP INDEX `index_on_id`" %m.name)
    end

    
	Lhm.change_table :archive_tickets, :atomic_switch => true do |m|
	  m.ddl("ALTER TABLE %s DROP PRIMARY KEY" % m.name)
	  m.ddl("ALTER TABLE %s ADD PRIMARY KEY(id,account_id)" % m.name)
	  m.ddl("ALTER TABLE %s DROP INDEX `index_on_id`" %m.name)
	end
  end

  def down
  end
end
