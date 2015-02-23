require 'xmlsimple'

class Integrations::GoogleContactsImporter
  include Integrations::GoogleContactsUtil
  include Helpdesk::ToggleEmailNotification
  def initialize (google_account=nil)
    @google_account = google_account
  end

  def self.sync_google_contacts_for_all_accounts 
    # The below query fetches GoogleAccount along with InstalledApplication's configs field through inner join.  So only if the google_contacts integration is enabled this will fetch the detail.
    google_accounts = Integrations::GoogleAccount.current_pod.find_all_installed_google_accounts
    google_accounts.each { |google_account|
#        sync_type = YAML::load(google_account.configs)[:inputs]["sync_type"]
      Account.reset_current_account
      begin
        if google_account.account.blank? or !google_account.account.active?
          Rails.logger.info "Account #{google_account.account.name} expired.  Google contacts syncing disabled."
        else
          goog_cnt_importer = Integrations::GoogleContactsImporter.new(google_account)
          #if Time.now > google_account.last_sync_time+86400 # Start the syncing only if the last sync time more than an hour.
            goog_cnt_importer.sync_google_contacts
          #end
        end
      rescue => err
        Rails.logger.error "Error while syncing google_contacts for account #{google_account.inspect}. \n#{err.message}\n#{err.backtrace.join("\n\t")}"
      end
    }
  end

  def import_google_contacts(options = {})
    options[:sync_type] = SyncType::IMPORT_EXPORT
    sync_google_contacts options
  end

  def sync_google_contacts(options = {})
    @google_account.account.make_current
    Rails.logger.info "###### Inside sync_google_contacts for account #{@google_account.account.name} from email #{@google_account.email}, with options=#{options.inspect} ######"
    overwrite_existing_user = options[:overwrite_existing_user].blank? ? @google_account.overwrite_existing_user : options[:overwrite_existing_user]
    sync_type = options[:sync_type].blank? ? SyncType::SYNC_CONTACTS : options[:sync_type]
    sync_stats = {:status=>:error} # If no exception occurs then the status will be reset with proper status else it will say in error status.
    begin
      # Do not proceed further if the status is still in 'progress'.
      @google_account.last_sync_status = {} if @google_account.last_sync_status.blank?
      raise "Syncing still in progress." if @google_account.last_sync_status[:status] == :progress
      # Check and Store the 'progress' status.
      @google_account.last_sync_status[:status] = :progress
      @google_account.save! unless @google_account.new_record?
      # Disbale notification before doing any other operations.
      disable_notification(@google_account.account)
      group_ids = options[:group_ids].blank? ? @google_account.sync_group_id.to_a : options[:group_ids]
      db_stats = handle_import_and_remove_discrepancy(sync_type, overwrite_existing_user, group_ids) 
      case sync_type
        when SyncType::IMPORT_EXPORT
          db_contacts = find_non_google_contacts
          google_stats = @google_account.batch_update_google_contacts(db_contacts, sync_type) 
        when SyncType::SYNC_CONTACTS
          db_contacts = find_updated_db_contacts
          @google_account.update_google_contacts(db_contacts, false, sync_type)
      end
      
      # Update the sync time and status
      @google_account.last_sync_time = DateTime.now+0.0001  # Storing 8secs forward.
      
      sync_stats = {:status=>:success, :db_stats => db_stats, :google_stats => google_stats}
    ensure
      # Enable notification before doing any other operations.
      enable_notification(@google_account.account) 
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
      users = @google_account.account.all_users.find(:all, :conditions => ["updated_at > ?  and active=?", last_sync_time, true])
    end
    Rails.logger.debug "#{users.length} users in db has been fetched. #{@google_account.email}"
    users.blank? ? [] : users
  end

  def find_non_google_contacts
    google_user_ids=GoogleContact.find(:all,:select=>'user_id').map {|i| i.user_id }
    users = User.find(:all, :conditions=>['id NOT IN (?) AND active = ? AND deleted = ?',google_user_ids, true, false])
    users.blank? ? [] : users
  end

  private
  
    def handle_import_and_remove_discrepancy(sync_type, overwrite_existing_user, group_ids)
      goog_contacts = []
      agg_db_stats = [[0,0,0],[0,0,0]]
      begin
        group_ids.each do |id|
          goog_contacts << @google_account.fetch_latest_google_contacts(1000, id, sync_type)
        end
        @google_account.batch_update_google_contacts(goog_contacts.first,sync_type) if sync_type == SyncType::IMPORT_EXPORT
        fetched_db_stats = update_db_contacts(goog_contacts.first, overwrite_existing_user)
        fetched_db_stats.each_index { |i|
          fetched_db_stats[i].each_index { |j|
            agg_db_stats[i][j] = agg_db_stats[i][j] + fetched_db_stats[i][j]
          }
        }
      end 
      agg_db_stats
    end

    def update_db_contacts(updated_goog_contacts_hash, overwrite_existing_user = true)
      stats=[0,0,0]; err_stats=[0,0,0]
      account = @google_account.account
      updated_goog_contacts_hash.each { |user|
        unless user.blank? or account.blank? or user.email.blank?
          begin
            sync_tag_id = @google_account.sync_tag.id unless @google_account.sync_tag.blank?
            if user.exist_in_db?
              if overwrite_existing_user # && user.deleted == false
                if sync_tag_id.blank? || user.tagged?(sync_tag_id)
                  next if user.agent? && user.deleted?
                  updated = user.save
                  updated ? (user.deleted ? stats[2] += 1 : stats[1] += 1) : (user.deleted ? err_stats[2] += 1 : err_stats[1] += 1) 
                  GoogleContact.find(:first,:conditions => ["user_id = ? AND google_account_id = ?",user.id,@google_account.id]).destroy if user.deleted
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

    def send_error_email (status, options={}) #possible dead code
      begin
        if options[:send_email]
          email_params = {:email => options[:email], :domain => options[:domain], :status =>  status}
          Admin::DataImportMailer.deliver_google_contacts_import_error_email(email_params)
        end
      rescue => e
        Rails.logger.error "ERROR: NOT ABLE SEND GOOGLE CONTACTS ERROR IMPORT MAIL.  \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      end
    end
end
