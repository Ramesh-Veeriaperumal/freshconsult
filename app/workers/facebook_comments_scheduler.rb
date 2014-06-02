class FacebookCommentsScheduler < BaseWorker

  sidekiq_options :queue => :facebook_comments_scheduler, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform
    if empty_queue?(Social::FbCommentsWorker.get_sidekiq_options["queue"])
      logger.info "Facebook Comments Worker initialized at #{Time.zone.now}"
      shards = Sharding.all_shards
      shards.each do |shard_name|
        shard_sym = shard_name.to_sym
        logger.info "shard_name is #{shard_name}"
        Sharding.run_on_shard(shard_name) do
          Sharding.run_on_slave do
            Social::FacebookPage.active.find_in_batches( 
              :joins => %(
                LEFT JOIN  accounts on accounts.id = social_facebook_pages.account_id 
                INNER JOIN `subscriptions` ON subscriptions.account_id = accounts.id),
              :conditions => "subscriptions.next_renewal_at > now() "
            ) do |page_block|
              page_block.each do |page|
                Account.reset_current_account
                page.account.make_current
                  Social::FbCommentsWorker.perform_async({
                    :account_id => page.account_id, 
                    :fb_page_id => page.id
                  }) 
              end          
            end
          end
        end
      end
    else
      logger.info "Facebook Comments Worker is already running . skipping at #{Time.zone.now}" 
    end
  end
end