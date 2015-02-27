class Integrations::SalesforceAccount < ActiveRecord::Base

  belongs_to :account

  belongs_to :installed_application, :class_name => 'Integrations::InstalledApplication'

  attr_accessible :last_sync_time, :pull_record_to_freshdesk, :push_record_to_salesforce, :pulled_existing_records, :pushed_existing_records

  named_scope :records_to_push, lambda { |sync_time| {:conditions => ["last_sync_time>=? AND push_record_to_salesforce=true", sync_time]}}

  named_scope :records_to_pull, lambda { |sync_time| {:conditions => ["last_sync_time>=? AND pull_record_to_freshdesk=true", sync_time]}}

  after_commit :sync_existing_contacts

  def sync_existing_contacts
    installed_application = Account.current.installed_applications.with_name("salesforce").first
    # If only to pull, then no need to sync
    if (installed_application && installed_application[:configs][:inputs]["sync_with_sf"] == "on" && installed_application[:configs][:inputs]["sf_sync_type"] != "pull" && !self.pushed_existing_records)
      Resque.enqueue(Integrations::Crm::BulkExportExisting, {:salesforce_account => self, :app_name => "salesforce", :sf_account_id => sf_account_id})
    end
  end

  

  # :sync_type, :sync_status, :next_sync_time

  # Looks like sync_type is redundant should check ??
  # And sync_status. I am using as different columns coz different processes are used for different cases

  # CONTACT_SYNC = 1
  # COMPANY_SYNC = 2

  # sync type has if contact sync or company sync

end