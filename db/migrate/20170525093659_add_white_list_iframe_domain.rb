class AddWhiteListIframeDomain < ActiveRecord::Migration
  include Redis::RedisKeys
  include Redis::OthersRedis

  shard :none
  
  def migrate(direction)
    self.send(direction)
  end

  def up
    iframe_allowed_pages = ['/support/home', '/support/solutions', '/support/discussions', '/widgets/feedback_widget/new']
    iframe_allowed_pages.each do |page|
      add_member_to_redis_set(IFRAME_WHITELIST_DOMAIN,page)
    end
  end

  def down
    remove_others_redis_key(IFRAME_WHITELIST_DOMAIN)
  end
end