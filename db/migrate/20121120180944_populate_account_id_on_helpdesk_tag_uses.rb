class PopulateAccountIdOnHelpdeskTagUses < ActiveRecord::Migration
  def self.up
  	execute("UPDATE helpdesk_tag_uses INNER JOIN helpdesk_tags ON helpdesk_tag_uses.tag_id=helpdesk_tags.id SET helpdesk_tag_uses.account_id=helpdesk_tags.account_id")
  end

  def self.down
  	execute("UPDATE helpdesk_tag_uses SET account_id = null")
  end
end
