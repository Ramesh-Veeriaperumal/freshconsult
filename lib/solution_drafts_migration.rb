class SolutionDraftsMigration
  class << self

    def perform(shard_name = :shard_1)
      Account.reset_current_account
      Sharding.run_on_shard(:shard_1) do
        Sharding.run_on_slave do
          ShardMapping.find_in_batches(:batch_size => 300, :conditions => ['status = ? AND shard_name = ?', 200, shard_name]) do |shard_mappings|
            shard_mappings.each do |shard_mapping|
              migrate_for_account(shard_mapping.account_id)
            end
          end
        end
      end
    end

    def migrate_for_account(account_id)
      Account.reset_current_account
      Sharding.select_shard_of(account_id) do
        begin
          current_account = Account.find(account_id).make_current
          p "*"*50
          p "Migration started for account_id #{Account.current.id}"
          drafts_folder_update(current_account)
          create_draft_for_existing(current_account)
        rescue Exception => e
          puts "-" * 50
          puts "Error while migrating drafts for Account: #{Account.current.id}"
          puts e.message
          puts "-" * 50
        end
      end
    end

    def drafts_folder_update(account)
      default_folder = account.solution_folders.where(:is_default => true).first
      default_folder.articles.update_all(:status => Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
      p "Drafts Folder migrated for account_id #{Account.current.id}"
    end

    def create_draft_for_existing(account)
      draft_articles = account.solution_articles.where('status = ?', Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
      draft_articles.each do |article|
        article.create_draft_from_article
        p "Article : #{article.id}"
      end
      p "Articles(Draft Status) migrated for account_id #{Account.current.id}"
    end

  end
end