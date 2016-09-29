#Remove this class after completly migrating to realtime facebook
module Facebook 
  module Graph
    class Posts
      
      include Facebook::Constants
      
      def initialize(fb_page, options = {})
        @account        =  options[:current_account] || Account.current
        @rest           =  Koala::Facebook::API.new(fb_page.page_token)
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
          ("facebook/core/#{clazz}").camelize.constantize.new(@fan_page, post[:id]).process
        end
      end
       
      def post_type(from)
        ("#{@fan_page.page_id}" == from) ? POST_TYPE[:status] : POST_TYPE[:post]
      end 
      
    end
  end
end

