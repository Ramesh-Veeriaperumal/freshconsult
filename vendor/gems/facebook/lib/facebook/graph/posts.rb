#Remove this class after completly migrating to realtime facebook
module Facebook 
  module Graph
    class Posts
      
      include Social::Util
      include Facebook::Constants
      
      def initialize(fb_page, options = {})
        @account        =  options[:current_account] || Account.current
        @rest           =  Koala::Facebook::API.new(fb_page.page_token)
        @dynamo_helper  =  Social::Dynamo::Facebook.new
        @fan_page       =  fb_page
      end
      
      def fetch_latest_posts
        posts = @rest.get_connections('me', 'feed', {:fields => "id, from, updated_time"})
        unless posts.blank?
          process_graph_feeds(posts)
          updated_time = Time.zone.parse(posts.first[:updated_time])       
          @fan_page.update_attributes({:fetch_since => updated_time.to_i}) unless updated_time.blank?
        end
      end
      
      private
      
      def process_graph_feeds(posts)
        posts.each do |post|
          post.symbolize_keys!
          next if @account.facebook_posts.find_by_post_id(post[:id])
          clazz     = post_type(post[:from]["id"])
          core_post = ("facebook/core/#{clazz}").camelize.constantize.new(@fan_page, post[:id])
          core_post.process(convert_to_ticket?(clazz), push_to_dynamo?(post[:id]))
        end
      end
       
      def post_type(from)
        (@fan_page.page_id == from) ? POST_TYPE[:status] : POST_TYPE[:post]
      end 
      
      def convert_to_ticket?(clazz)
        clazz == POST_TYPE[:post] and @fan_page.import_visitor_posts
      end
      
      def push_to_dynamo?(post_id)
        return false unless Account.current.features?(:social_revamp)
        dynamo_keys  = dynamo_hash_and_range_key(@fan_page.default_stream.id)
        !@dynamo_helper.has_parent_feed?(Time.now.utc, dynamo_keys, post_id)
      end
           
    end
  end
end

