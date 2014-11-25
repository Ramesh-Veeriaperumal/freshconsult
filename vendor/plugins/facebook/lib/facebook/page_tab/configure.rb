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

      attr_accessor :page_token, :app_id, :graph

      def initialize(page,app_id)
        #if app_id is present it is from the new app
        #populating page token also
        if page
          if app_id
            @app_id = FacebookConfig::PAGE_TAB_APP_ID
            @page_token = page.page_token_tab
          else
            @app_id = FacebookConfig::APP_ID
            @page_token = page.page_token
          end
          @graph = Koala::Facebook::API.new(@page_token) if @page_token
        end
      end

      # returns nil if there is any Exception
      def execute(verb,*options)
        begin
          (options.blank?  ? self.send(verb) : self.send(verb,options)) if @graph
        rescue Exception => e
          return nil
          #Handle Exception Later
        end
      end

      private

      #Add a page tab to your Facebook Account
      def add
        @graph.put_connections("me", "tabs",{
                                 :access_token => @page_token,
                                 :app_id => @app_id
        })
      end

      #Remove a page from your Facebook Account
      #Remove a page tab from realtime app doesn't work this is bug in facebook
      #https://developers.facebook.com/bugs/503381706394259
      #This works for visble page tab though

      def remove
        @graph.delete_connections("me", "tabs/app_#{@app_id}",{
                                    :access_token => @page_token
        })
      end

      #Update's a Custom name to a page tab
      def update(options)
        @graph.put_connections("me", "tabs/app_#{@app_id}",{
                                 :access_token => @page_token,
                                 :custom_name => options[0]
        })
      end

      # list all available page tabs on a page
      # right now facebook allows only one page tab per app
      # realtime and page tab cannot be in the same app
      # realtime app by default retruns []
      # if an app return [] that means page token is valid
      # if an app retruns [{}] that means a page tab is already added
      def get
        page_tab = @graph.get_connections("me", "tabs/#{@app_id}",{
                                            :access_token => @page_token
        })
        page_tab.blank? ? [] : page_tab.first
      end


    end
  end
end
