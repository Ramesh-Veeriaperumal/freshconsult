class RemoveQuotesFromContacts < ActiveRecord::Migration
  def self.up
    Account.active_accounts.each do |account|
      account.make_current
      account.users.find(:all, :conditions => [' name RLIKE ? ', '^"|"$' ]).each do |user|
        user_name =  user.name.gsub!(/\A"|"\z/,'')
        ActiveRecord::Base.connection.execute("update users set name = '#{user_name}' where id = #{user.id}")
      end
    end
  end

  def self.down
  end
end
