namespace :facebook do
  desc 'Check for New facebook feeds..'

  task :fetch => :environment do 
    queue_name = "FacebookWorker"
    if queue_empty?(queue_name)
      puts "Facebook Worker initialized at #{Time.zone.now}"
      Account.active_accounts.each do |account|
          Resque.enqueue( Social::FacebookWorker ,{:account_id => account.id} )           
      end
    else
      puts "Facebook Worker is already running . skipping at #{Time.zone.now}" 
    end
  end

  task :comments => :environment do
    queue_name = "facebook_comments_worker"
    if queue_empty?(queue_name)
      puts "Facebook Comments Worker initialized at #{Time.zone.now}"
        Social::FacebookPage.active.find_in_batches( 
          :joins => %(
            LEFT JOIN  accounts on accounts.id = social_facebook_pages.account_id 
            INNER JOIN `subscriptions` ON subscriptions.account_id = accounts.id),
          :conditions => "subscriptions.next_renewal_at > now() "
        ) do |page_block|
          page_block.each do |page|
              Resque.enqueue(Social::FacebookCommentsWorker ,
                {:account_id => page.account_id, :fb_page_id => page.id} ) 
          end          
        end
    else
      puts "Facebook Comments Worker is already running . skipping at #{Time.zone.now}" 
    end
  end


  def queue_empty?(queue_name)
    queue_length = Resque.redis.llen "queue:#{queue_name}"
    puts "current #{queue_name} length is #{queue_length}"
    queue_length < 1
  end
end