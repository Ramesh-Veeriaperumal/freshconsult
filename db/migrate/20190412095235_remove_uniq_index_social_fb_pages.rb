class RemoveUniqIndexSocialFbPages < ActiveRecord::Migration
  shard :all

  def self.up
    execute('ALTER TABLE social_facebook_pages DROP INDEX facebook_page_id') if check_index(:facebook_page_id)
    execute('ALTER TABLE social_facebook_pages DROP INDEX index_page_id') if check_index(:index_page_id)
  end

  def self.down
    execute('ALTER TABLE social_facebook_pages ADD CONSTRAINT facebook_page_id unique(page_id)') unless check_index(:facebook_page_id)
    execute('ALTER TABLE social_facebook_pages ADD CONSTRAINT index_page_id unique(page_id)') unless check_index(:index_page_id)
  end

  def self.check_index(index_name)
    index_exists?(:social_facebook_pages, 'page_id', name: index_name)
  end
end