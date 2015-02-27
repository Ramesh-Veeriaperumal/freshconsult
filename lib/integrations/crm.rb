class Integrations::Crm
  QUEUE = :sync_crm

  # yet to create and update entries in installed_applications - will do once UI is ready
  # UI - CSS and jQuery validations are pending
  class Contact
    extend Resque::AroundPerform
    include Integrations::Crm::Salesforce

    @queue = QUEUE

    def self.perform(options)
      puts "Integrations::Crm::Contact called........!!!!!!!!"
      if(options[:app_name] == "salesforce")
        sync_contacts_with_salesforce(options[:user]["user"], options[:sf_account_id])
      end
    end
  end

  class Company
    extend Resque::AroundPerform
    include Integrations::Crm::Salesforce

    @queue = QUEUE

    def self.perform(options)
      puts "Integrations::Crm::Company called........!!!!!!!!"
      # To make existing records work
      # bulk_export_existing_records_to_salesforce(options)
      if(options[:app_name] == "salesforce")
        sync_companies_with_salesforce(options[:company]["company"])
      end
    end
  end

  class BulkExport
    extend Resque::AroundPerform
    include Integrations::Crm::Salesforce

    @queue = QUEUE

    def self.perform(options)
      puts "Integrations::Crm::BulkExport called.........!!!!!!!!!!"
      if(options[:app_name] == "salesforce")
        installed_application = Account.current.installed_applications.with_name("salesforce").first
        # If only to pull, then no need to sync
        if (installed_application && installed_application[:configs][:inputs]["sync_with_sf"] == "on" && installed_application[:configs][:inputs]["sf_sync_type"] != "pull")
          # Call respective blocks
          if (options[:params]["type"] == "contact")
            # Only push if name and email are present i.e., compulsory attributes
            if (["name", "email"] - options[:params]["customers"]["fields"].keys).empty?
              bulk_export_contacts_to_salesforce(options)
            end
          else
            # Only push if name is present i.e., compulsory attributes
            if (["name"] - options[:params]["customers"]["fields"].keys).empty?
              bulk_export_companies_to_salesforce(options)
            end
          end
        end
      end
    end
  end

  class BulkExportExisting
    extend Resque::AroundPerform
    include Integrations::Crm::Salesforce

    @queue = QUEUE

    def self.perform(options)
      if(options[:app_name] == "salesforce")
        bulk_export_existing_records_to_salesforce(options)
      end
    end
  end
end