module CronWebhooks
  class TrafficSwitchFetchAccounts < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_traffic_switch_fetch_accounts, retry: 0, dead: true, failures: :exhausted

    def perform(args)
      perform_block(args, &method(:fetch_accounts))
    end

    private

      def fetch_accounts
        bucket_name = 'log-bucket-production'
        free_account_ids = []
        paid_account_details = []
        free_account_domains = []
        paid_account_domains = {}
        plan_details_hash = SubscriptionPlan.all.map { |i| [i.id, i.name] }.to_h

        plan_details_hash.keys.each do |key|
          paid_account_domains[key] = []
        end

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

        suspended_domains = []
        domain_details = []
        Sharding.run_on_all_slaves do
          current_shard_name = ActiveRecord::Base.current_shard_selection.shard.to_s
          Subscription.find_each do |subscription|
            if subscription.state.eql? 'suspended'
              domain =  DomainMapping.find_by_account_id(subscription.account_id).try(:domain)
              suspended_domains << domain
            else
              account_shard_name = ShardMapping.find_by_account_id(account.id).shard_name
              if account_shard_name == current_shard_name
                domain = DomainMapping.find_by_account_id(subscription.account_id).try(:domain)
                account_shard_name.slice! 'shard_'
                state = (subscription.state.eql? 'active') ? 'paid' : subscription.state
                domain_details << domain + ' ' + account_shard_name + ' ' + state
              end
            end
          end
        end

        File.open('/tmp/suspended_domains.lst', 'w') do |f|
          suspended_domains.each { |domain| f.puts(domain) }
        end
        s3.put_object(key: 'haproxy-domains/suspended_domains.lst', bucket: bucket_name, body: IO.read('/tmp/suspended_domains.lst'))

        File.open('/tmp/domain_details.map', 'w') do |f|
          domain_details.each { |domain| f.puts(domain) }
        end
        s3.put_object(key: 'haproxy-domains/domain_details.map', bucket: bucket_name, body: IO.read('/tmp/domain_details.map'))

        # The S3 File (haproxy-domains/billed_domains.lst) holds the billed domains which should not be treated
        # as sample domains during FREE or PARTIAL Traffic switch
        s3 = Aws::S3::Client.new(region: 'us-east-1')
        billed_domains_list = []
        begin
          billed_domains_object = s3.get_object(key: 'haproxy-domains/billed_domains.lst', bucket: bucket_name)
          billed_domains_list = billed_domains_object.body.string.split('\n').uniq
        rescue Aws::S3::Errors::ServiceError
          Rails.logger.info 'S3 File - haproxy-domains/billed_domains.lst not found'
        end

        free_account_ids.each do |acc_id|
          domain = DomainMapping.find_by_account_id_and_portal_id(acc_id, nil).try(:domain)
          free_account_domains << domain if domain && !(billed_domains_list.include? domain)
        end

        paid_account_details.each do |acc_id, plan_id|
          domain = DomainMapping.find_by_account_id_and_portal_id(acc_id, nil).try(:domain)
          paid_account_domains[plan_id] << domain if domain && !(billed_domains_list.include? domain)
        end

        File.open('/tmp/free_domains.lst', 'w') do |f|
          free_account_domains.each { |domain| f.puts(domain) }
        end

        s3.put_object(key: 'haproxy-domains/free_domains.lst', bucket: bucket_name, body: IO.read('/tmp/free_domains.lst'))

        file_name_mappings = { 0 => '/tmp/t1.lst', 1 => '/tmp/t2.lst', 2 => '/tmp/t3.lst', 3 => '/tmp/t4.lst' }
        file_object_mappings = {}
        file_name_mappings.each { |i, file_name| file_object_mappings[i] = File.open(file_name, 'w+') }

        paid_account_domains.each_value do |domains_arr|
          domains_arr.each_with_index do |dom, index|
            key = index % 4
            file_object_mappings[key].puts(dom)
          end
        end

        file_object_mappings.each_value(&:close)

        file_name_mappings.each_value do |path|
          name = File.basename(path)
          s3.put_object(key: "haproxy-domains/#{name}", bucket: bucket_name, body: IO.read(path))
        end
      end
  end
end
