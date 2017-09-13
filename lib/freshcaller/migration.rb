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
      return unless response.code == 200
      save_freshcaller_account(response)
      disable_freshfone_feature
      enable_freshcaller_feature
      save_freshcaller_agents(response)
      retrieve_account_details
      upload_to_s3
      initiate_migration
    end

    def save_freshcaller_account(response)
      Rails.logger.info "Save Freshcaller account :: Account :: #{current_account.id}" 
      Freshcaller::Account.create(
        account_id: current_account.id,
        freshcaller_account_id: params[:freshcaller_account_id] || response[:freshcaller_account_id],
        domain: params[:freshcaller_account_domain] || response[:freshcaller_account_domain]
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

    def save_freshcaller_agents(response)
      Rails.logger.info "Save freshcaller agents :: Account :: #{current_account.id}"
      current_account.make_current
      account_admin.agent.create_freshcaller_agent(
        fc_user_id: params[:fc_user_id] || response[:agent]['id'],
        fc_enabled: true
      )
    end

    def account_admin
      roles ||= current_account.roles.where(name: 'Account Administrator').first
      users ||= current_account.users.where(privileges: roles.privileges).reorder('id asc')
      user ||= users.first
    end

    def account_migration_location
      MIGRATION_LOCATION.join(current_account.id.to_s, '')
    end

    def retrieve_account_details
      fetch_business_calendars(current_account.id)
      fetch_freshfone_groups(current_account.id)
      fetch_freshfone_numbers(current_account.id)
      fetch_caller_ids(current_account.id)
      fetch_freshfone_users(current_account.id)
      fetch_freshfone_objects(current_account.id)
      fetch_freshfone_credits(current_account.id)
    end

    def upload_to_s3
      Rails.logger.info "S3 Upload :: Account :: #{current_account.id}"
      Dir.foreach(account_migration_location) do |file|
        next if ['.', '..'].include?(file)
        data = File.read(account_migration_location + file)
        AwsWrapper::S3Object.store(S3_LOCATION + "/#{current_account.freshcaller_account.freshcaller_account_id}/#{file}", 
                                   data, FreshcallerConfig['s3_bucket'],
                                   { content_type: 'json',
                                    acl: 'bucket-owner-full-control' })
      end
      FileUtils.rm_rf(account_migration_location)
    end

    def initiate_migration
      Rails.logger.info "Freshcaller request to migrate for Account :: #{current_account.id}"
      protocol = Rails.env.development? ? 'http://' : 'https://'
      freshcaller_request({ helpkit_account: current_account.id,
                            requestor: params[:email],
                            helpkit_domain: current_account.full_domain,
                            account_id: current_account.freshcaller_account.freshcaller_account_id },
                            "#{protocol}#{current_account.freshcaller_account.domain}/migrate",
                            :post)
    end
  end
end
