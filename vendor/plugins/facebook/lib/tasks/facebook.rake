namespace :facebook do
  desc 'Check for New facebook feeds..'

  PREMIUM_ACC_IDS = {:staging => [390], :production => [18685,39190]}
  # rake task to fetch FB private messages.
  task :fetch => :environment do

    queue_name = "FacebookWorker"
    if queue_empty?(queue_name)
      puts "Facebook Worker initialized at #{Time.zone.now}"
      Sharding.execute_on_all_shards do
        Account.active_accounts.each do |account|
          next if check_if_premium?(account) || account.facebook_pages.empty?
          Resque.enqueue(Facebook::Worker::FacebookMessage ,{:account_id => account.id} )
        end
      end
    else
      puts "Facebook Worker is already running . skipping at #{Time.zone.now}"
    end
  end

  task :premium => :environment do
    queue_name = "premium_facebook_worker"
    premium_acc_ids = Rails.env.production? ? PREMIUM_ACC_IDS[:production] : PREMIUM_ACC_IDS[:staging]
    if queue_empty?(queue_name)
      premium_acc_ids.each do |account_id|
        Resque.enqueue(Facebook::Worker::PremiumFacebookWorker, {:account_id => account_id })
      end
    else
      puts "Premium Facebook Worker is already running . skipping at #{Time.zone.now}"
    end
  end

  # this needs to be removed when complete migrations goes for realtime
  task :comments => :environment do
    queue_name = "facebook_comments_worker"
    if queue_empty?(queue_name)
      puts "Facebook Comments Worker initialized at #{Time.zone.now}"
      shards = Sharding.all_shards
      shards.each do |shard_name|
        shard_sym = shard_name.to_sym
        puts "shard_name is #{shard_name}"
        Sharding.run_on_shard(shard_name) {
          Social::FacebookPage.active.find_in_batches(
            :joins => %(
              LEFT JOIN  accounts on accounts.id = social_facebook_pages.account_id
            INNER JOIN `subscriptions` ON subscriptions.account_id = accounts.id),
            :conditions => "subscriptions.next_renewal_at > now() "
          ) do |page_block|
            page_block.each do |page|
              Resque.enqueue(Social::FacebookCommentsWorker ,
                             {:account_id => page.account_id, :fb_page_id => page.id} ) unless page.account.features?(:facebook_realtime)
            end
          end
        }
      end
    else
      puts "Facebook Comments Worker is already running . skipping at #{Time.zone.now}"
    end
  end

  task :subscribe => :environment do
    Sharding.execute_on_all_shards do
      Account.active_accounts.each do |account|
        account.facebook_pages.each do |fb_page|
          fb_page.register_stream_subscription
        end
      end
    end
  end

  task :subscribe_facebook_realtime, [:from_account_id,:to_account_id,:shard] => :environment do |task,args|
    Sharding.run_on_shard(args.shard) do
      (args.from_account_id.to_i..args.to_account_id.to_i).each do |account_id|
        account = Account.find_by_id(account_id)
        if account && account.features?(:facebook)
          account.features.send(:facebook_realtime).create
          account.facebook_pages.each do |fb_page|
            fb_page.register_stream_subscription
          end
        end
      end
    end
  end

  #migrating existing users from one page_tab app to another
  task :migrate_users => :environment do
    valid_accounts = {}
    valid_accounts[:accounts] = []
    valid_accounts[:admin_emails] = []
    Sharding.execute_on_all_shards do
      Account.active_accounts.each do |account|
        next unless account.features?(:facebook_page_tab)
        puts "account id =========> #{account.id} migration strated"
        account.facebook_pages.each do |fb_page|
          begin
            fb_tab = Facebook::PageTab::Configure.new(fb_page)
            tab = fb_tab.execute("get")
            unless tab.blank?
              valid_accounts[:accounts] << account.id
              valid_accounts[:admin_emails] << account.account_managers.first.email
              fb_page.update_attribute(:page_token_tab,"")
            end
          rescue Exception => e
            puts "call failed for #{fb_page.id} and #{account.id} ==========> #{e.inspect}"
          end
        end
        puts "account id =========> #{account.id} migration ended"
      end
      puts "#{valid_accounts.inspect}"
      puts "#{valid_accounts[:admin_emails].join(',')}"
    end
  end

  #rake task for continous polling need to start in background
  desc 'Process data from sqs'
  task :realtime => :environment do
    $sqs_facebook.poll("Facebook::Core::Parser","parse",
                       :batch_size => 10,
                       :initial_timeout => false)
  end

  def queue_empty?(queue_name)
    queue_length = Resque.redis.llen "queue:#{queue_name}"
    puts "current #{queue_name} length is #{queue_length}"
    queue_length < 1
  end

  def check_if_premium?(account)
    Rails.env.production? ? PREMIUM_ACC_IDS[:production].include?(account.id) :
      PREMIUM_ACC_IDS[:staging].include?(account.id)
  end

end