require 'xmlsimple'

class Integrations::GoogleContactsImporter
  include Integrations::GoogleContactsUtil

  def initialize (google_account=nil)
    @google_account = google_account
  end

  def self.sync_google_contacts_for_all_accounts 
    # The below query fetches GoogleAccount along with InstalledApplication's configs field through inner join.  So only if the google_contacts integration is enabled this will fetch the detail.
    google_accounts = Integrations::GoogleAccount.find_all_installed_google_accounts
    google_accounts.each { |g_account|
#        sync_type = YAML::load(g_account.configs)[:inputs]["sync_type"]
      begin
        sync_type = g_account.sync_type
        goog_cnt_importer = Integrations::GoogleContactsImporter.new(g_account)
        goog_cnt_importer.sync_google_contacts(sync_type)
      rescue => err
        puts "Error while syncing google_contacts for account #{google_account.email}, sync_type=#{sync_type}. \n#{err.message}\n#{err.backtrace.join("\n\t")}"
      end
    }
  end

  def import_google_contacts(overwrite_existing_user = nil)
    @google_account.account = Account.find(@google_account.account_id) unless @google_account.account.blank?
    sync_google_contacts(SyncType::OVERWRITE_REMOTE, overwrite_existing_user)
  end

  def sync_google_contacts(sync_type = SyncType::OVERWRITE_REMOTE, overwrite_existing_user = nil)
    puts "###### Inside sync_google_contacts for account #{@google_account.email}, sync_type=#{sync_type} ######"
    no_of_synced_contacts = nil
    overwrite_existing_user = @google_account.overwrite_existing_user if overwrite_existing_user.blank?
    begin
      disable_notification(@google_account.account)
      case sync_type
        when SyncType::OVERWRITE_LOCAL # Export
          db_contacts = find_updated_db_contacts
          # Fetch the contact in google first
          goog_contacts = @google_account.find_latest_google_contacts
          # Remove discrepancy method also updates google_id in the db_contacts. This is will be useful in deciding update or add of a contact while exporting.
          remove_discrepancy(db_contacts, goog_contacts, true)
          @google_account.batch_update_google_contacts(db_contacts)
          no_of_synced_contacts = db_contacts.length
        when SyncType::OVERWRITE_REMOTE # Import
          goog_contacts = @google_account.find_latest_google_contacts
          update_db_contacts(goog_contacts, overwrite_existing_user)
          no_of_synced_contacts = goog_contacts.length
        when SyncType::MERGE_LOCAL # Merge Freshdesk precedence  
          db_contacts = find_updated_db_contacts
          goog_contacts = @google_account.find_latest_google_contacts
          remove_discrepancy(db_contacts, goog_contacts, true)
          @google_account.batch_update_google_contacts(db_contacts)
          update_db_contacts(goog_contacts, overwrite_existing_user)
          no_of_synced_contacts = db_contacts.length + goog_contacts.length
        when SyncType::MERGE_REMOTE # Merge Google precedence
          db_contacts = find_updated_db_contacts
          goog_contacts = @google_account.find_latest_google_contacts
          remove_discrepancy(db_contacts, goog_contacts, false)
          @google_account.batch_update_google_contacts(db_contacts)
          update_db_contacts(goog_contacts, overwrite_existing_user)
          no_of_synced_contacts = db_contacts.length + goog_contacts.length
      end
      @google_account.last_sync_time = DateTime.now
      @google_account.save!
    ensure
      enable_notification(@google_account.account)
    end
    puts "###### Completed sync_google_contacts for account #{@google_account.email}, sync_type=#{sync_type} ######"
    return no_of_synced_contacts
  end

  def find_updated_db_contacts()
    last_sync_time = @google_account.last_sync_time
    sync_tag_id = @google_account.last_sync_time
    if sync_tag_id.blank?
      users = User.find(:all, :conditions => ["updated_at > ? and account_id = ?", last_sync_time, @google_account.account]);
    else
      users = User.find(:all, :joins=>"INNER JOIN helpdesk_tag_uses ON helpdesk_tag_uses.taggable_id=users.id and helpdesk_tag_uses.taggable_type='User'", 
                        :conditions => ["updated_at > ? and account_id = ? and helpdesk_tag_uses.tag_id=?", last_sync_time, google_account.account, sync_tag_id])
    end
    puts "#{users.length} users in db has been fetched. #{google_account.email}"
    return users
  end

  private
  
    def update_db_contacts(updated_goog_contacts_hash, overwrite_existing_user = true)
  #   puts "Inside update_db_contacts #{updated_goog_contacts_hash.inspect}"
      account = @google_account.account
      updated_goog_contacts_hash.each { |user|
        unless user.blank? || account.blank?
          puts user.inspect
          begin
            sync_tag_id = @google_account.sync_tag.id unless @google_account.sync_tag.blank?
            if user.exist_in_db?
              puts "overwrite_existing_user #{sync_tag_id} #{user.tagged?(sync_tag_id)}"
              if overwrite_existing_user # && user.deleted == false
                if sync_tag_id.blank? || user.tagged?(sync_tag_id)
                  updated = user.save
                  puts "User #{user.email} update successful :: #{updated}"
                end
              end
            else
              added = user.signup # This method will take care of properly saving and sending activation instructions if needed etc.
              puts "User #{user.email} signup successful :: #{added}"
            end
          rescue => e
            puts "Problem in updating google contact #{user.email}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
          end
        end
      }
    end
end
