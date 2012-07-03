class ConvertCcEmailArrayToHash < ActiveRecord::Migration
  def self.up
    Account.all.each do |account|
      cc_not_null_tickets = account.tickets.visible.find(:all, :conditions => ["cc_email is not null"])
      cc_not_null_tickets.each do |tkt|
        cc_email_val = tkt.cc_email
        if cc_email_val.is_a?(Array)
          cc_hash = {:cc_emails => "#{cc_email_val}", :fwd_emails => []}
          tkt.cc_email = cc_hash
          tkt.send(:update_without_callbacks)
        end
      end
    end
  end

  def self.down
  end
end
