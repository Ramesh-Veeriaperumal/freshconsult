class ConvertCcEmailHashValues < ActiveRecord::Migration
  def self.up
    Account.all.each do |account|
      cc_not_null_tickets = account.tickets.visible.find(:all, :conditions => ["cc_email is not null"])
      cc_not_null_tickets.each do |tkt|
        cc_email = tkt.cc_email
        if (cc_email.is_a?(Hash) and !cc_email.has_key?(:version)) 
          tkt.cc_email = tkt.convert_cc_email_hash
          tkt.send(:update_without_callbacks)
        end
      end
    end
  end

  def self.down
  end
end
