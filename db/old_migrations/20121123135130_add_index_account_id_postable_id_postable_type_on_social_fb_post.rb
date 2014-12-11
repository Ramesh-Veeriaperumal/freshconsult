class AddIndexAccountIdPostableIdPostableTypeOnSocialFbPost < ActiveRecord::Migration
  def self.up
  	execute <<-SQL
  		CREATE INDEX `index_social_fb_posts_account_id_postable_id_postable_type` ON social_fb_posts (`account_id`,`postable_id`,`postable_type`(15))
  	SQL
  end

  def self.down
  	execute <<-SQL
  		DROP INDEX `index_social_fb_posts_account_id_postable_id_postable_type` ON social_fb_posts
  	SQL
  end
end
