module CronWebhooks
  class TrafficSwitchFetchAccounts < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_traffic_switch_fetch_accounts, retry: 0, dead: true, failures: :exhausted

    S3_BUCKET_NAME = 'fd-haproxy'.freeze
    S3_BUCKET_PATH = "haproxy-domains/#{ENV['AWS_REGION']}".freeze

    def perform(args)
      perform_block(args, &method(:fetch_accounts))
    end

    private

      def fetch_accounts
        @s3 = Aws::S3::Client.new(region: 'us-east-1')

        upload_domain_shard_mapping
        upload_free_paid_domains
      end

      def upload_free_paid_domains
        free_account_ids, paid_account_details = fetch_free_paid_accounts

        billed_domains = fetch_billed_domains
        free_account_domains = fetch_free_domains(free_account_ids, billed_domains)
        paid_account_domains = fetch_paid_domains(paid_account_details, billed_domains)

        write_and_upload_file('free_domains.lst', free_account_domains)
        bucket_and_upload(paid_account_domains)
      end

      def fetch_free_paid_accounts
        free_account_ids = []
        paid_account_details = []

        Sharding.run_on_all_slaves do
          Subscription.where(state: %w[free active paid], subscription_currency_id: 1).each do |subscription|
            if %w[free active].include?(subscription.state) && subscription.amount.zero?
              any_active_agent = Agent.where('account_id = ? and last_active_at >= ?', subscription.account_id, 7.days.ago).count
              free_account_ids << subscription.account_id if any_active_agent > 0
            elsif subscription.state.eql?('active') && (subscription.amount > 0)
              amount_paid = subscription.amount / subscription.renewal_period
              paid_account_details << [subscription.account_id, subscription.subscription_plan_id] if (amount_paid > 1) && (amount_paid <= 100)
            end
          end
        end

        [free_account_ids, paid_account_details]
      end

      def fetch_paid_domains(paid_account_details, billed_domains)
        plan_details_hash = SubscriptionPlan.all.map { |i| [i.id, i.name] }.to_h
        paid_account_domains = {}

        plan_details_hash.keys.each do |key|
          paid_account_domains[key] = []
        end

        paid_account_details.each do |acc_id, plan_id|
          domain = DomainMapping.where(account_id: acc_id, portal_id: nil).first.try(:domain)
          paid_account_domains[plan_id] << domain if domain && !(billed_domains.include? domain)
        end
        paid_account_domains
      end

      def fetch_free_domains(free_accounts, billed_domains)
        free_account_domains = []

        free_accounts.each do |acc_id|
          domain = DomainMapping.where(account_id: acc_id, portal_id: nil).first.try(:domain)
          free_account_domains << domain if domain && !(billed_domains.include? domain)
        end
        free_account_domains
      end

      # The S3 File (#{S3_BUCKET_PATH}/billed_domains.lst) holds the billed domains which should not be treated
      # as sample domains during FREE or PARTIAL Traffic switch
      def fetch_billed_domains
        begin
          billed_domains_object = @s3.get_object(key: "#{S3_BUCKET_PATH}/billed_domains.lst", bucket: S3_BUCKET_NAME)
          return billed_domains_object.body.string.split('\n').uniq
        rescue Aws::S3::Errors::ServiceError
          Rails.logger.info "S3 File - #{S3_BUCKET_PATH}/billed_domains.lst not found"
          return []
        rescue StandardError => e
          Rails.logger.error "Error fetching billed domains : #{e.message}"
          return []
        end
      end

      def upload_domain_shard_mapping
        suspended_domains = []
        domain_details = []

        Sharding.run_on_all_slaves do
          current_shard_name = ActiveRecord::Base.current_shard_selection.shard.to_s
          Subscription.find_each do |subscription|
            begin
              if subscription.state.eql? 'suspended'
                domain = DomainMapping.where(account_id: subscription.account_id).first.try(:domain)
                suspended_domains << domain
              else
                account_shard_name = ShardMapping.lookup_with_account_id(subscription.account_id).shard_name
                if account_shard_name == current_shard_name
                  domain = DomainMapping.where(account_id: subscription.account_id).first.try(:domain)
                  account_shard_name.slice! 'shard_'
                  state = subscription.state.eql?('active') ? 'paid' : subscription.state
                  domain_details << domain + ' ' + account_shard_name + ' ' + state
                end
              end
            rescue StandardError => e
              Rails.logger.error "upload_domain_shard_mapping :: Error while generating map :: #{e.message}"
              NewRelic::Agent.notice_error(e)
            end
          end
        end

        write_and_upload_file('suspended_domains.lst', suspended_domains)
        write_and_upload_file('domain_details.map', domain_details)
      end

      def write_and_upload_file(file_name, content)
        file_path = "/tmp/#{file_name}"
        File.open(file_path, 'w') do |f|
          content.each { |line| f.puts(line) }
        end
        @s3.put_object(key: "#{S3_BUCKET_PATH}/#{file_name}", bucket: S3_BUCKET_NAME, body: IO.read("/tmp/#{file_name}"))
      end

      def bucket_and_upload(paid_domains)
        file_name_mappings = { 0 => '/tmp/t1.lst', 1 => '/tmp/t2.lst', 2 => '/tmp/t3.lst', 3 => '/tmp/t4.lst' }
        file_object_mappings = {}
        file_name_mappings.each { |i, file_name| file_object_mappings[i] = File.open(file_name, 'w+') }

        paid_domains.each_value do |domains_arr|
          domains_arr.each_with_index do |dom, index|
            key = index % 4
            file_object_mappings[key].puts(dom)
          end
        end

        file_object_mappings.each_value(&:close)

        file_name_mappings.each_value do |path|
          name = File.basename(path)
          @s3.put_object(key: "#{S3_BUCKET_PATH}/#{name}", bucket: S3_BUCKET_NAME, body: IO.read(path))
        end
      end
  end
end
