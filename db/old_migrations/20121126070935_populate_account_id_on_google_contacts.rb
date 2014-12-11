class PopulateAccountIdOnGoogleContacts < ActiveRecord::Migration
  def self.up
  	execute <<-SQL
  		UPDATE google_contacts INNER JOIN google_accounts ON google_contacts.google_account_id = google_accounts.id
  		SET google_contacts.account_id = google_accounts.account_id
  	SQL
  end

  def self.down
  	execute <<-SQL
  		UPDATE google_contacts SET account_id = NULL
  	SQL
  end
end
