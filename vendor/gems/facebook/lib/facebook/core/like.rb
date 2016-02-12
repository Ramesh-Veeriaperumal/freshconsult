module Facebook
  module Core
    class Like
      
      include Facebook::Constants
      include Facebook::RedisMethods
      
      attr_accessor :fan_page, :account, :type, :feed_id
      
      def initialize(fan_page, feed_id)
        @account  = Account.current
        @fan_page = fan_page
        @feed_id  = feed_id
        @type     = POST_TYPE[:like]
      end
      
      def add
        update_like_in_redis(redis_key, 1)
      end
          
      def remove
        update_like_in_redis(redis_key, -1)
      end
      
      private
      def redis_key
        hash_key = "#{account.id}_#{self.fan_page.default_stream.id}"
        "#{self.feed_id}::#{hash_key}"
      end
      
    end
  end
end
