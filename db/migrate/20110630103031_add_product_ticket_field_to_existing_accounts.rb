class AddProductTicketFieldToExistingAccounts < ActiveRecord::Migration
  def self.up
    Account.all.each do |account|
      t_field = account.ticket_fields.create!({
        :name => "product",
        :label => "Product",
        :description => "Select the product, the ticket belongs to.",
        :active => true,
        :field_type => "default_product",
        :required => false,
        :visible_in_portal => true,
        :editable_in_portal => true,
        :required_in_portal => false,
        :required_for_closure => false
      })
    end
  end

  def self.down
  end
end
