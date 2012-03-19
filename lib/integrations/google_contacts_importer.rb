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
        if google_account.account.blank? or !google_account.account.active?
          Rails.logger.info "Account #{google_account.account.name} expired.  Google contacts syncing disabled."
        else
          goog_cnt_importer = Integrations::GoogleContactsImporter.new(google_account)
          if Time.now > google_account.last_sync_time+5 # Start the syncing only if the last sync time more than an hour.
            goog_cnt_importer.sync_google_contacts
          end
        end
      rescue => err
        Rails.logger.error "Error while syncing google_contacts for account #{google_account.inspect}. \n#{err.message}\n#{err.backtrace.join("\n\t")}"
      end
    }
  end

  def import_google_contacts(options = {})
    options[:sync_type] = SyncType::OVERWRITE_REMOTE
    sync_google_contacts options
  end

  def sync_google_contacts(options = {})
    Rails.logger.info "###### Inside sync_google_contacts for account #{@google_account.account.name} from email #{@google_account.email}, with options=#{options.inspect} ######"
    overwrite_existing_user = options[:overwrite_existing_user].blank? ? @google_account.overwrite_existing_user : options[:overwrite_existing_user]
    sync_type = options[:sync_type].blank? ? @google_account.sync_type : options[:sync_type]
    sync_stats = {:status=>:error} # If no exception occurs then the status will be reset with proper status else it will say in error status.
    begin
      # Do not proceed further if the status is still in 'progress'.
      @google_account.last_sync_status = {} if @google_account.last_sync_status.blank?
      raise "Syncing still in progress." if @google_account.last_sync_status[:status] == :progress
      # Check and Store the 'progress' status.
      @google_account.last_sync_status[:status] = :progress
      @google_account.save! unless @google_account.new_record?
      # Disbale notification before doing any other operations.
      EmailNotification.disable_notification(@google_account.account)
      case sync_type
        when SyncType::OVERWRITE_LOCAL # Export
          db_contacts = find_updated_db_contacts
          # Fetch the contact in Google first
          goog_contacts = @google_account.fetch_latest_google_contacts
          # Remove discrepancy method also updates google_id in the db_contacts. This is will be useful in deciding update or add of a contact while exporting.
          remove_discrepancy_and_set_google_data(@google_account, db_contacts, goog_contacts, "DB", true)
          google_stats = @google_account.batch_update_google_contacts(db_contacts)
        when SyncType::OVERWRITE_REMOTE # Import
          db_stats = handle_import_and_remove_discrepancy(nil, overwrite_existing_user, nil)
        when SyncType::MERGE_LOCAL # Merge Freshdesk precedence  
          db_contacts = find_updated_db_contacts
          db_stats = handle_import_and_remove_discrepancy(db_contacts, overwrite_existing_user, "DB")
          google_stats = @google_account.batch_update_google_contacts(db_contacts)
        when SyncType::MERGE_REMOTE # Merge Google precedence
          db_contacts = find_updated_db_contacts
          db_stats = handle_import_and_remove_discrepancy(db_contacts, overwrite_existing_user, "GOOGLE")
          google_stats = @google_account.batch_update_google_contacts(db_contacts)
        when SyncType::MERGE_LATEST # Take latest record as precedence
          db_contacts = find_updated_db_contacts
          db_stats = handle_import_and_remove_discrepancy(db_contacts, overwrite_existing_user, "LATEST")
          google_stats = @google_account.batch_update_google_contacts(db_contacts)
      end 
      # Update the sync time and status
      @google_account.last_sync_time = DateTime.now+0.0001 unless @google_account.donot_update_sync_time # Storing 8secs forward.
      sync_stats = {:status=>:success, :db_stats => db_stats, :google_stats => google_stats}
    ensure
      # Enable notification before doing any other operations.
      EmailNotification.enable_notification(@google_account.account) 
      Rails.logger.info "last_sync_status #{sync_stats.inspect}"
      @google_account.last_sync_status = sync_stats
      @google_account.save! unless @google_account.new_record?
      send_success_email(@google_account.last_sync_status, options) # Send email after saving the status into db.
    end
    Rails.logger.info "###### Completed sync_google_contacts for account #{@google_account.account.name} from email #{@google_account.email}, with options=#{options.inspect} ######"
    return @google_account
  end

  def find_updated_db_contacts()
    last_sync_time = @google_account.last_sync_time
    sync_tag_id = @google_account.sync_tag_id
    unless sync_tag_id.blank?
      # If sync tag is not specified then users in db will not be pushed back to Google.
      # deletion handling is Disabled for now. Remove the deleted check in the query to enable it.
      users = @google_account.account.all_users.find(:all, :include=>:google_contacts, :joins=>"INNER JOIN helpdesk_tag_uses ON helpdesk_tag_uses.taggable_id=users.id and helpdesk_tag_uses.taggable_type='User'", 
                        :conditions => ["updated_at > ? and helpdesk_tag_uses.tag_id=? and deleted=?", last_sync_time, sync_tag_id, false])
    end
    Rails.logger.debug "#{users.length} users in db has been fetched. #{@google_account.email}"
    return users
  end

  private
  
    def handle_import_and_remove_discrepancy(db_contacts, overwrite_existing_user, discre_precedence)
      goog_contacts = []
      agg_db_stats = [[0,0,0],[0,0,0]]
      begin
        goog_contacts = @google_account.fetch_latest_google_contacts(MAX_RESULTS)
        remove_discrepancy_and_set_google_data(@google_account, db_contacts, goog_contacts, discre_precedence) unless db_contacts.blank?
        fetched_db_stats = update_db_contacts(goog_contacts, overwrite_existing_user)
        fetched_db_stats.each_index { |i|
          fetched_db_stats[i].each_index { |j|
            agg_db_stats[i][j] = agg_db_stats[i][j] + fetched_db_stats[i][j]
          }
        }
      end while goog_contacts.length > MAX_RESULTS
      agg_db_stats
    end

    def update_db_contacts(updated_goog_contacts_hash, overwrite_existing_user = true)
      stats=[0,0,0]; err_stats=[0,0,0]
      account = @google_account.account
      updated_goog_contacts_hash.each { |user|
        unless user.blank? || account.blank?
          begin
            sync_tag_id = @google_account.sync_tag.id unless @google_account.sync_tag.blank?
            if user.exist_in_db?
              if overwrite_existing_user # && user.deleted == false
                if sync_tag_id.blank? || user.tagged?(sync_tag_id)
                  updated = user.save
                  updated ? (user.deleted ? stats[2] += 1 : stats[1] += 1) : (user.deleted ? err_stats[2] += 1 : err_stats[1] += 1) 
                  Rails.logger.info "User #{user.email} update successful :: #{updated}, errors: #{user.errors.full_messages}"
                end
              end
            else
              added = user.signup # This method will take care of properly saving and sending activation instructions if needed etc.
              added ? stats[0] += 1 : err_stats[0] += 1
              Rails.logger.info "User #{user.email} signup successful :: #{added}, errors: #{user.errors.full_messages}"
            end
          rescue => e
            Rails.logger.error "Problem in updating google contact #{user.email}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
          end
        end
      }
      Rails.logger.debug "Finished update_db_contacts #{stats}  #{err_stats}"
      return stats, err_stats
    end

    def send_success_email (status, options={})
      begin
        if options[:send_email]
          email_params = {:email => options[:email], :domain => options[:domain], :status =>  status}
          Rails.logger.info "Sending google import mail with params #{email_params}"
          Admin::DataImportMailer.deliver_google_contacts_import_email(email_params)
        end
      rescue => e
        Rails.logger.error "ERROR: NOT ABLE SEND GOOGLE CONTACTS IMPORT MAIL.  \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      end
    end

    def send_error_email (status, options={})
      begin
        if options[:send_email]
          email_params = {:email => options[:email], :domain => options[:domain], :status =>  status}
          Admin::DataImportMailer.deliver_google_contacts_import_error_email(email_params)
        end
      rescue => e
        Rails.logger.error "ERROR: NOT ABLE SEND GOOGLE CONTACTS ERROR IMPORT MAIL.  \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      end
    end

    MAX_RESULTS = 1000
end
