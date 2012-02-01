require 'xmlsimple'

class Integrations::GoogleContactsImporter
  include Integrations::GoogleContactsUtil

  def initialize (google_account=nil)
    @google_account = google_account
  end

  def self.sync_google_contacts_for_all_accounts 
    # The below query fetches GoogleAccount along with InstalledApplication's configs field through inner join.  So only if the google_contacts integration is enabled this will fetch the detail.
    google_accounts = Integrations::GoogleAccount.find_all_installed_google_accounts
    google_accounts.each { |google_account|
#        sync_type = YAML::load(google_account.configs)[:inputs]["sync_type"]
      begin
        goog_cnt_importer = Integrations::GoogleContactsImporter.new(google_account)
        if Time.now > google_account.last_sync_time+86400 # Start the syncing only if the last sync time more than a day.
          goog_cnt_importer.sync_google_contacts
        end
      rescue => err
        puts "Error while syncing google_contacts for account #{google_account.inspect}. \n#{err.message}\n#{err.backtrace.join("\n\t")}"
      end
    }
  end

  def import_google_contacts(options = {})
    @google_account.account = Account.find(@google_account.account_id) unless @google_account.account.blank?
    options[:sync_type] = SyncType::OVERWRITE_REMOTE
    sync_google_contacts(options)
  end

  def sync_google_contacts(options = {})
    puts "###### Inside sync_google_contacts for account #{@google_account.account.name} from email #{@google_account.email}, with options=#{options.inspect} ######"
    overwrite_existing_user = options[:overwrite_existing_user].blank? ? @google_account.overwrite_existing_user : options[:overwrite_existing_user]
    sync_type = options[:sync_type].blank? ? @google_account.sync_type : options[:sync_type]
    status = {:status=>:error} # If no exception occurs then the status will be reset with proper status else it will say in error status.
    begin
      EmailNotification.disable_notification(@google_account.account)
      case sync_type
        when SyncType::OVERWRITE_LOCAL # Export
          db_contacts = find_updated_db_contacts
          # Fetch the contact in Google first
          goog_contacts = @google_account.find_latest_google_contacts
          # Remove discrepancy method also updates google_id in the db_contacts. This is will be useful in deciding update or add of a contact while exporting.
          remove_discrepancy(db_contacts, goog_contacts, "DB", true)
          google_stats = @google_account.batch_update_google_contacts(db_contacts)
        when SyncType::OVERWRITE_REMOTE # Import
          goog_contacts = @google_account.find_latest_google_contacts
          db_stats = update_db_contacts(goog_contacts, overwrite_existing_user)
        when SyncType::MERGE_LOCAL # Merge Freshdesk precedence  
          db_contacts = find_updated_db_contacts
          goog_contacts = @google_account.find_latest_google_contacts
          remove_discrepancy(db_contacts, goog_contacts,"DB")
          google_stats = @google_account.batch_update_google_contacts(db_contacts)
          db_stats = update_db_contacts(goog_contacts, overwrite_existing_user)
        when SyncType::MERGE_REMOTE # Merge Google precedence
          db_contacts = find_updated_db_contacts
          goog_contacts = @google_account.find_latest_google_contacts
          remove_discrepancy(db_contacts, goog_contacts,"GOOGLE")
          google_stats = @google_account.batch_update_google_contacts(db_contacts)
          db_stats = update_db_contacts(goog_contacts, overwrite_existing_user)
        when SyncType::MERGE_LATEST # Take latest record as precedence
          db_contacts = find_updated_db_contacts
          goog_contacts = @google_account.find_latest_google_contacts
          remove_discrepancy(db_contacts, goog_contacts)
          google_stats = @google_account.batch_update_google_contacts(db_contacts)
          db_stats = update_db_contacts(goog_contacts, overwrite_existing_user)
      end
      # Update the sync time and status
      @google_account.last_sync_time = DateTime.now 
      status = {:status=>:success, :db_stats => db_stats, :google_stats => google_stats}
    ensure
      # Enable notification before doing any other operations.
      EmailNotification.enable_notification(@google_account.account) 
      puts "last_sync_status #{status.inspect} #{@google_account.is_primary?}"
      @google_account.last_sync_status = status
      @google_account.save! if @google_account.is_primary?
      send_success_email(status, options) # Send email after saving the status into db.
    end
    puts "###### Completed sync_google_contacts for account #{@google_account.account.name} from email #{@google_account.email}, with options=#{options.inspect} ######"
    return @google_account
  end

  def find_updated_db_contacts()
    last_sync_time = @google_account.last_sync_time
    sync_tag_id = @google_account.sync_tag_id
    if sync_tag_id.blank?
      users = User.find(:all, :conditions => ["updated_at > ? and account_id = ?", last_sync_time, @google_account.account]);
    else
      users = User.find(:all, :joins=>"INNER JOIN helpdesk_tag_uses ON helpdesk_tag_uses.taggable_id=users.id and helpdesk_tag_uses.taggable_type='User'", 
                        :conditions => ["updated_at > ? and account_id = ? and helpdesk_tag_uses.tag_id=?", last_sync_time, @google_account.account_id, sync_tag_id])
    end
    puts "#{users.length} users in db has been fetched. #{@google_account.email}"
    return users
  end

  private
  
    def update_db_contacts(updated_goog_contacts_hash, overwrite_existing_user = true)
  #   puts "Inside update_db_contacts #{updated_goog_contacts_hash.inspect}"
      stats=[0,0,0]; err_stats=[0,0,0]
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
                  updated ? (user.deleted ? stats[2] += 1 : stats[1] += 1) : (user.deleted ? err_stats[2] += 1 : err_stats[1] += 1) 
                  puts "User #{user.email} update successful :: #{updated}, errors: #{user.errors.full_messages}"
                end
              end
            else
              added = user.signup # This method will take care of properly saving and sending activation instructions if needed etc.
              added ? stats[0] += 1 : err_stats[0] += 1
              puts "User #{user.email} signup successful :: #{added}, errors: #{user.errors.full_messages}"
            end
          rescue => e
            puts "Problem in updating google contact #{user.email}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
          end
        end
      }
      return stats, err_stats
    end

    def send_success_email (status, options={})
      if options[:send_email]
        email_params = {:email => options[:email], :domain => options[:domain], :status =>  status}
        Admin::DataImportMailer.deliver_google_contacts_import_email(email_params)
      end
    end

    def send_success_email (status, options={})
      if options[:send_email]
        email_params = {:email => options[:email], :domain => options[:domain], :status =>  status}
        Admin::DataImportMailer.deliver_google_contacts_import_error_email(email_params)
      end
    end
end
