# This class is responsible for configuration of page tab
# * Usage obj = Facebook::PageTab::Configure(facebook_page,app_id)
# * obj.execute(verd) valid verbs['get','add','remove','update']
# * Can create a page tab in facebook
# * obj.execute('add')
# * Can remove a page tab from facebook
# * obj.execute('remove')
# * Can update a page tab name with custom name
# * obj.execute('update','custom_name')

module Facebook
  module PageTab
    class Configure
      
      #By default this call is set for realtime
      #Pass app id as "page_tab" for page_tab app
      def self.new(page=nil,app_id=nil)
        KoalaConnector.new(page,app_id)
      end
    end

    class KoalaConnector
      
      include Facebook::Constants

      include Facebook::Constants

      attr_accessor :page_token, :app_id, :graph

      def initialize(page,app_id)
        #if app_id is present it is from the new app
        #populating page token also
        if page
          @app_id     = Facebook::Tokens.new(app_id).tokens[:app_id]
          @page_token = page.page_token
          @page_id = page.id
          @graph      = Koala::Facebook::API.new(@page_token) if @page_token
        end
      end

      # returns nil if there is any Exception
      def execute(verb,*options)
        begin
          (options.blank?  ? self.safe_send(verb) : self.safe_send(verb,options)) if @graph
        rescue => e
          return nil
          #Handle Exception Later
        end
      end

      private

      #Subscribe for realtime updates from the app

      def subscribe_realtime
        data = {
          'access_token' => @page_token,
          'subscribed_fields' => FB_WEBHOOK_EVENTS
        }
        RestClient.post "#{FACEBOOK_GRAPH_URL}/#{GRAPH_API_VERSION}/me/subscribed_apps", data.to_json, :content_type => :json, :accept => :json
      rescue StandardError => e
        Rails.logger.error "Exception occurred while subscribing to account #{Account.current.id} for page #{@page_id} Exception: #{e.inspect}"
      end

      #Remove realtime subscribe for realtime updates from the app
      def unsubscribe_realtime
        @graph.delete_connections("me", "subscribed_apps")
      end

      #Update's a Custom name to a page tab
      def update(options)
        @graph.put_connections("me", "tabs/app_#{@app_id}",{
                                 :access_token => @page_token,
                                 :custom_name => options[0]
        })
      end
    end
  end
end
