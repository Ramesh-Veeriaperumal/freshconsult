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
      return unless has_freshfone_account?
      raise "Domain occupied" unless check_domain_available?
      response = freshcaller_signup if params[:account_creation]
      save_freshcaller_account(response)
      enable_freshcaller_feature
      save_freshcaller_agents(response)
      retrieve_account_details
      expire_freshfone_account
      upload_to_s3
      initiate_migration
    end

    def check_domain_available?
      return true if !params[:account_creation]
      response = freshcaller_request({}, "#{FreshcallerConfig['signup_domain']}/domain_available?domain=#{FreshcallerConfig['domain_prefix']}#{::Account.current.domain}", :get)
      Rails.logger.info "Domain check :: #{response.symbolize_keys!}"
      response[:is_available]
    end

    def has_freshfone_account?
      ::Account.current && ::Account.current.freshfone_account
    end

    def freshcaller_signup
      signup_response = create_freshcaller_account
      return unless signup_response.code == 200
      signup_response
    end

    def save_freshcaller_account(response)
      Rails.logger.info "Save Freshcaller account :: Account :: #{current_account.id}" 
      Freshcaller::Account.create(
        account_id: current_account.id,
        freshcaller_account_id: params[:freshcaller_account_id] || response[:freshcaller_account_id],
        domain: params[:freshcaller_account_domain] || response[:freshcaller_account_domain]
      )
    end

    def expire_freshfone_account
      current_account.freshfone_account.update_column(:state, Freshfone::Account::STATE_HASH[:expired])
    end

    def enable_freshcaller_feature
      Rails.logger.info "Enable freshcaller & widget :: Account :: #{current_account.id}"
      current_account.add_feature(:freshcaller)
      current_account.add_feature(:freshcaller_widget)
    end

    def save_freshcaller_agents(response)
      Rails.logger.info "Save freshcaller agents :: Account :: #{current_account.id}"
      current_account.make_current
      return create_freshcaller_agent if params[:fc_user_id].present?
      account_admin.agent.create_freshcaller_agent(
        fc_user_id: response[:user]['id'],
        fc_enabled: true
      )
    end

    def create_freshcaller_agent
      agent = current_account.users.where(email: params[:fc_user_email]).first.agent
      agent.create_freshcaller_agent(
        fc_user_id: params[:fc_user_id],
        fc_enabled: true
      )
    end

    def account_admin
      current_account.account_managers.first
    end

    def account_migration_location
      MIGRATION_LOCATION.join(current_account.id.to_s, '')
    end

    def retrieve_account_details
      fetch_business_calendars
      fetch_freshfone_groups
      fetch_freshfone_numbers
      fetch_caller_ids
      fetch_freshfone_users
      fetch_freshfone_objects
      fetch_freshfone_credits
      fetch_agent_limits
    end

    def upload_to_s3
      Rails.logger.info "S3 Upload :: Account :: #{current_account.id}"
      s3_client = Aws::S3::Client.new(region: FreshcallerConfig['region'])
      bucket = Aws::S3::Bucket.new(FreshcallerConfig['s3_bucket'], { client: s3_client })
      Dir.foreach(account_migration_location) do |file|
        next if ['.', '..'].include?(file)
        data = File.read(account_migration_location + file)
        bucket.put_object({ key: S3_LOCATION + "/#{current_account.freshcaller_account.freshcaller_account_id}/#{file}", 
                            body: data, 
                            server_side_encryption: 'AES256', 
                            content_type: 'json', 
                            acl: 'bucket-owner-full-control'
                          })
      end
      FileUtils.rm_rf(account_migration_location)
    end

    def initiate_migration
      Rails.logger.info "Freshcaller request to migrate for Account :: #{current_account.id}"
      protocol = Rails.env.development? ? 'http://' : 'https://'
      freshcaller_request({ helpkit_account: current_account.id,
                            requestor: params[:email],
                            helpkit_domain: current_account.full_domain,
                            access_token: current_account.roles.account_admin.first.users.first.single_access_token,
                            plan: params[:plan_name],
                            account_id: current_account.freshcaller_account.freshcaller_account_id },
                            "#{protocol}#{current_account.freshcaller_account.domain}/migrate",
                            :post)
    end
  end
end
