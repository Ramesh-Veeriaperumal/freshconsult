namespace :ebay_daily_api_report do 
  desc "Fetch the daily api usage of all ebay accounts"
  task :intimate => :environment do

    include Redis::IntegrationsRedis
    include Redis::RedisKeys

    file_name = "ebay_api_count_details.csv"
    date = Time.now.utc.strftime("%Y-%m-%d")
    csv_string = CSVBridge.generate do |csv| 
      csv << ["account_id", "account_domain", "ebay_account_id", "ebay_account_name", "api_count"]
      Sharding.execute_on_all_shards do
        Ecommerce::EbayAccount.current_pod.where(:status => Ecommerce::Account::ACCOUNT_STATUS[:active] ).find_in_batches(:batch_size => 200) do |ebay_accounts|
          ebay_accounts.each do |ebay_account| 
            account = ebay_account.account
            account.make_current 
            key = EBAY_ACCOUNT_THRESHOLD_COUNT % { :date => date, :account_id => account.id, :ebay_account_id =>  ebay_account.id}
            api_count = get_integ_redis_key(key)
            csv << [account.id, account.full_domain, ebay_account.id, ebay_account.name, api_count.to_i]
          end
        end
      end
    end
    file_path = File.join(Rails.root.to_s ,file_name)
    File.delete(file_path) if File.exist?(file_name)
      File.open(file_path, 'w') {|f| f.write(csv_string) }
    EcommerceNotifier.daily_api_usage(file_name)
  end
end

