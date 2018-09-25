namespace :traffic_switch do

  desc "Fetch free and paid account samples for traffic switching"
  task :fetch_accounts => :environment do
    bucket_name = "log-bucket-production"
    free_account_ids = []
    paid_account_details = []  
    free_account_domains = []
    paid_account_domains = {}
    plan_details_hash = SubscriptionPlan.all.map { |i| [i.id, i.name ]}.to_h

    plan_details_hash.keys.each do | key | 
      paid_account_domains[key] = []
    end

    Sharding.run_on_all_slaves do
      Subscription.where(:state => ["free","active","paid"], :subscription_currency_id => 1).each do | subscription | 
        if ["free", "active"].include?(subscription.state) and subscription.amount == 0
          any_active_agent = Agent.where("account_id = ? and last_active_at >= ?", subscription.account_id, 7.days.ago).count
          free_account_ids << subscription.account_id if any_active_agent > 0 
        elsif subscription.state.eql?("active") and subscription.amount > 0
          amount_paid = subscription.amount / subscription.renewal_period
          paid_account_details << [subscription.account_id, subscription.subscription_plan_id ] if (amount_paid > 1 and amount_paid <= 100)
        end
      end
    end

    free_account_ids.each do | acc_id | 
      domain = DomainMapping.find_by_account_id_and_portal_id(acc_id, nil).try(:domain)
      free_account_domains << domain if domain
    end

    paid_account_details.each do | acc_id, plan_id | 
      domain = DomainMapping.find_by_account_id_and_portal_id(acc_id, nil).try(:domain)
      paid_account_domains[plan_id] << domain if domain
    end

    File.open("/tmp/free_domains.lst", "w") do |f|
      free_account_domains.each { |domain| f.puts(domain) }
    end

    s3 = Aws::S3::Client.new(region: 'us-east-1')
    s3.put_object(key: "haproxy-domains/free_domains.lst", bucket: bucket_name, body: IO.read("/tmp/free_domains.lst"))

    file_name_mappings = { 0 => "/tmp/t1.lst", 1 => "/tmp/t2.lst", 2 => "/tmp/t3.lst", 3 => "/tmp/t4.lst"}
    file_object_mappings = {}
    file_name_mappings.each { |i, file_name| file_object_mappings[i] = File.open(file_name, "w+") }

    paid_account_domains.each do | plan, domains_arr | 
      domains_arr.each_with_index do | dom, index | 
        key = index % 4
        file_object_mappings[key].puts(dom)
      end
    end

    file_object_mappings.each { | index, file | file.close }

    file_name_mappings.each do | index, path|
      name = File.basename(path)
      s3.put_object(key: "haproxy-domains/#{name}", bucket: bucket_name, body: IO.read(path))
    end
  end
end

