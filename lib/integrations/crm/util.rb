module Integrations::Crm::Util
  include Integrations::OauthHelper

  def sync_contacts
    # To check bulk import call
    unless Thread.current["disable_crm_sync_#{Account.current.id}"].nil?
      return
    end
    # check for rake job. Also will not sync if the contact is deleted or email is empty
    unless Account.current.nil? || self.deleted || self.email.nil?
      installed_application = Account.current.installed_applications.with_name("salesforce").first
      # If only to pull, then no need to sync
      if (!installed_application.nil? && installed_application[:configs][:inputs]["sync_with_sf"] == "on" && installed_application[:configs][:inputs]["sf_sync_type"] != "pull")
        # Finding account id from salesforce, with company id
        unless self.company_id.nil?
          ir = Integrations::IntegratedResource.find_by_installed_application_id_and_local_integratable_id_and_local_integratable_type(installed_application.id, self.company_id, Company.name)
          if ir.nil?
            company = Company.find_by_id(self.company_id)
            query = "SELECT Name FROM Account WHERE Name LIKE '#{company.name}'"
            json_response = JSON.parse Integrations::Crm::Contact.get_object(query, installed_application)[:text]
            if json_response["totalSize"] > 0
              sf_account_id = json_response["records"][0]["attributes"]["url"].split('/').last
            end
          else
            sf_account_id = ir.remote_integratable_id
          end
        end
        # If the account is not present and to push only limited contacts
        if installed_application[:configs][:inputs]["contacts_sync_type"] == "required" && sf_account_id.nil?
          return
        end
        Resque.enqueue(Integrations::Crm::Contact, {:user => self, :app_name => "salesforce", :sf_account_id => sf_account_id})
      end
    end
  end

  def sync_companies
    # To check bulk import call
    unless Thread.current["disable_crm_sync_#{Account.current.id}"].nil?
      return
    end
    # To check for rake job
    unless Account.current.nil?
      installed_application = Account.current.installed_applications.with_name("salesforce").first
      # If only to pull, then no need to sync
      if (!installed_application.nil? && installed_application[:configs][:inputs]["sync_with_sf"] == "on" && installed_application[:configs][:inputs]["sf_sync_type"] != "pull")
        Resque.enqueue(Integrations::Crm::Company, {:company => self, :app_name => "salesforce"})
      end
    end
  end
end