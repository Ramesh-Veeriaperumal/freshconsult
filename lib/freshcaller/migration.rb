module Freshcaller
  module Migration
    include Freshcaller::AccountMigration
    include Freshcaller::NumberMigration
    include Freshcaller::RuleMigration
    include Freshcaller::UserMigration
    include Freshcaller::JwtAuthentication

    S3_LOCATION = 'freshcaller_migration'.freeze
    MIGRATION_LOCATION = Rails.root.join('migrations', '').freeze

    def migrate_account
      FileUtils.mkdir_p account_migration_location
      response = create_freshcaller_account(current_account.id) if params[:account_creation]
      save_freshcaller_account(response)
      disable_freshfone_feature
      enable_freshcaller_feature
      retrieve_account_details
      upload_to_s3(params[:freshcaller_account_id] || response[:freshcaller_account_id])
      initiate_migration(response)
    end

    def save_freshcaller_account(response)
      Rails.logger.info "Save Freshcaller account :: Account :: #{current_account.id}"
      Freshcaller::Account.create(
        account_id: current_account.id,
        freshcaller_account_id: params[:freshcaller_account_id] || response[:freshcaller_account_id],
        domain:  params[:freshcaller_account_domain] || response[:freshcaller_account_domain]
      )
    end

    def disable_freshfone_feature
      Rails.logger.info "Disable Freshfone feature :: Account :: #{current_account.id}"
      current_account.features.freshfone.destroy
    end

    def enable_freshcaller_feature
      Rails.logger.info "Enable freshcaller :: Account :: #{current_account.id}"
      current_account.add_feature(:freshcaller)
    end

    def account_migration_location
      MIGRATION_LOCATION.join(current_account.id.to_s, '')
    end

    def retrieve_account_details
      fetch_business_calendars(current_account.id)
      fetch_freshfone_groups(current_account.id)
      fetch_freshfone_numbers(current_account.id)
      fetch_caller_ids(current_account.id)
      fetch_freshfone_objects(current_account.id)
      fetch_freshfone_users(current_account.id)
      fetch_freshfone_credits(current_account.id)
    end

    def upload_to_s3(freshcaller_account_id)
      Rails.logger.info "S3 Upload :: Account :: #{current_account.id}"
      Dir.foreach(account_migration_location) do |file|
        next if ['.', '..'].include?(file)
        data = File.read(account_migration_location + file)
        AwsWrapper::S3Object.store(S3_LOCATION + "/#{freshcaller_account_id}/#{file}", 
                                   data, FreshcallerConfig['s3_bucket'],
                                   { content_type: 'json',
                                    acl: 'bucket-owner-full-control' })
      end
      FileUtils.rm_rf(account_migration_location)
    end

    def initiate_migration(account_detail)
      Rails.logger.info "Freshcaller request to migrate for Account :: #{current_account.id}"
      protocol = Rails.env.development? ? 'http://' : 'https://'
      freshcaller_request({ helpkit_account: current_account.id,
                            requestor: params[:email],
                            helpkit_domain: current_account.full_domain,
                            account_id: params[:freshcaller_account_id] || account_detail[:freshcaller_account_id] },
                            #"#{protocol}#{FreshcallerConfig['domain_prefix']}#{params[:freshcaller_account_domain] || account_detail[:freshcaller_account_domain]}/migrate"
                            "#{protocol}#{FreshcallerConfig['domain_prefix']}d2badcff.ngrok.io:3000/migrate",
                            :post)
    end
  end
end
