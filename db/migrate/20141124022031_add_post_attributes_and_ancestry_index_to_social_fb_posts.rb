class AddPostAttributesAndAncestryIndexToSocialFbPosts < ActiveRecord::Migration 
  shard :all
  
  def self.up
    Lhm.change_table :social_fb_posts, :atomic_switch => true do |m|
      m.ddl("ALTER TABLE %s ADD COLUMN post_attributes text" % m.name)
      m.ddl("ALTER TABLE %s ADD COLUMN ancestry varchar(255)" % m.name)
      m.ddl("ALTER TABLE %s ADD INDEX `account_ancestry_index` (`account_id`, `ancestry`(30)) " % m.name)
      m.ddl("ALTER TABLE %s ADD INDEX `index_social_fb_posts_on_post_id` (`account_id`, `post_id`(30)) " % m.name)
    end
  end

  def self.down
    Lhm.change_table :social_fb_posts, :atomic_switch => true do |m|
      m.ddl("ALTER TABLE %s DROP COLUMN post_attributes " % m.name)
      m.ddl("ALTER TABLE %s DROP INDEX `account_ancestry_index` " % m.name)
      m.ddl("ALTER TABLE %s DROP COLUMN ancestry " % m.name)
      m.ddl("ALTER TABLE %s DROP INDEX `index_social_fb_posts_on_post_id` " % m.name)
    end
  end
  
end
