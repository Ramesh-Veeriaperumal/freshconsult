namespace :marketplace_sync do

  ##### USAGE:
  ##### rake marketplace_sync:ni ACCOUNT_ID=1
  desc "Sync Marketplace installed native integrations with helpkit data"
  task :ni => :environment do
    include Marketplace::ApiMethods

    if ENV['ACCOUNT_ID'].blank?
      puts "Rake expects ACCOUNT_ID !!"
      exit(1)
    end

    Sharding.select_shard_of(ENV['ACCOUNT_ID']) do
      Sharding.run_on_slave do
        account = Account.find(ENV['ACCOUNT_ID'])
        account.make_current

        # Get all installed native integrations from marketplace
        installed_ni_payload = account_payload(Marketplace::ApiEndpoint::ENDPOINT_URL[:installed_extensions] % 
                  { :product_id => PRODUCT_ID, :account_id => Account.current.id},
                  {}, {:type => Marketplace::Constants::EXTENSION_TYPE[:ni]})
        installed_ni_response = get_api(installed_ni_payload, MarketplaceConfig::ACC_API_TIMEOUT)
        if error_status?(installed_ni_response)
          puts "Error in fetching installed native integrations"
          return
        else
          puts "Fetched installed native integrations"
        end

        # Delete all installed native integrations in marketplace
        installed_ni_response.body.each do |installed_ni|
          delete_params = { :extension_id => installed_ni['extension_id']
                          }
          delete_response = uninstall_extension(delete_params)
          if error_status?(delete_response)
            puts "Error in Deleting Native Integrations"
            return
          else
            puts "Deleted"
          end
        end

        Integrations::Application.where(:account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID).each do |application|
          installed_app = application.installed_applications[0]

          unless installed_app.blank?
            # Fetch latest detail of installed native integrations
            latest_details_response = ni_latest_details(application.name)
            if error_status?(latest_details_response)
              puts "Error in fetching ni details of #{application.name}"
              return
            else
              puts "Fetched details for #{application.name}"
            end
            
            # Install ni in marketplace
            extension_details = latest_details_response.body
            install_params = { :extension_id => extension_details['extension_id'],
                               :configs => installed_app.configs, 
                               :type => Marketplace::Constants::EXTENSION_TYPE[:ni],
                               :enabled => Marketplace::Constants::EXTENSION_STATUS[:enabled],
                             }
            install_extension_response = install_extension(install_params)
            if error_status?(install_extension_response)
              puts "Error in installing ni : #{application.name}"
              return
            else
              puts "Installed : #{application.name}"
            end
          end
        end

        Account.reset_current_account
      end
    end
  end
end