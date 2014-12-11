class AddPageTokenTab < ActiveRecord::Migration
  shard :none
  def self.up
    Lhm.change_table :social_facebook_pages,:atomic_switch => true do |m|
      m.ddl("alter table %s add column page_token_tab varchar(255)" % m.name)
    end
  end

  def self.down
  	Lhm.change_table :social_facebook_pages,:atomic_switch => true do |m|
      m.ddl("alter table %s drop page_token_tab" % m.name)
    end
  end
end
