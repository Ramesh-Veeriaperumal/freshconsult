#This class is responsible for communication with facebook
# * builds the authorization url
# * create's facebook page objects (Social::FacebookPage)
# * updates facebookpage token if any page tab is added
module Facebook
  module Oauth
    class FbClient

      attr_accessor :fb_app_id, :fb_app_secret, :call_back_url, :oauth, :app_type

      REALTIME_BLOCK = Proc.new { |pages, oauth_access_token|
        graph = Koala::Facebook::API.new(oauth_access_token)
        profile = graph.get_object("me")
        profile_id=profile["id"]
        fb_pages = Array.new
        pages.each do |page|
          page.symbolize_keys!
          page_id = page[:id]
          unless Account.current.facebook_pages.find_by_page_id(page[:id])
            page_source = Social::FacebookPageMapping.find_by_facebook_page_id(page[:id])
            if page_source
              source_account = page_source.shard.domains.main_portal.first
              if source_account
                source_string = "#{source_account.domain}"
                page_id = nil
              end
            end
          end
          page_info = graph.get_object(page[:id])
          page_picture = graph.get_picture(page[:id],{:type => "small"})
          page_info.symbolize_keys!
          fb_pages << {
            :profile_id => profile_id ,
            :access_token =>oauth_access_token,
            :page_id=> page_id,
            :page_name => page_info[:name],
            :page_token => page[:access_token],
            :page_img_url => page_picture || Facebook::Oauth::Constants::DEFAULT_PAGE_IMG_URL,
            :page_link => page_info[:link] ,
            :fetch_since => 0,
            :reauth_required => false,
            :source => source_string,
            :last_error => nil
          } unless page[:access_token].blank?

        end
        fb_pages
      }

      PAGE_TAB_BLOCK = Proc.new{ |tabs_added|
        if Account.current
          page_ids = tabs_added.keys
          page_tabs = Account.current.facebook_pages.find_all_by_page_id(page_ids)
          @edit_tab = true unless page_tabs.blank?
          page_tabs.each do |page_tab|
            page_tab.update_attribute(:page_token_tab, page_tab.page_id) if tabs_added[page_tab.page_id.to_s]
          end
        end
      }

      # if app_id is present it is the new app
      # call_back_url is the url where facebook would redirect back with code after it authorizes
      def initialize(app_id = nil, call_back_url = nil)
        @fb_app_id = FacebookConfig::APP_ID
        @fb_app_secret = FacebookConfig::SECRET_KEY
        @call_back_url = call_back_url
        @app_type = Facebook::Oauth::Constants::REALTIME
        if app_id
          @fb_app_id = FacebookConfig::PAGE_TAB_APP_ID
          @fb_app_secret = FacebookConfig::PAGE_TAB_SECRET_KEY
          @app_type = Facebook::Oauth::Constants::PAGE_TAB
        end
        @oauth = Koala::Facebook::OAuth.new(@fb_app_id, @fb_app_secret, @call_back_url)
      end


      # Returns the complete url the client should hit inorder to authorize with facebook
      # params[state] is the session state object
      def authorize_url(state, page_tab = false)
        if page_tab
          permissions = Facebook::Oauth::Constants::PAGE_TAB_PERMISSION.join(',')
          url = Facebook::Oauth::Constants::PAGE_TAB_URL
        else
          permissions = Facebook::Oauth::Constants::PERMISSION.join(',')
          url = Facebook::Oauth::Constants::URL
        end
        fb_params = "?client_id=#{@fb_app_id}&"+
          "redirect_uri=#{@call_back_url}&"+
          "state=#{state}&scope=#{permissions}"
        auth_url = url + fb_params
      end

      # gets the access token and page token once code is passed
      # returns all the pages if @app_type = "realtime"
      # update the pages with page_token_tab  if @app_type = "page_tab"
      def auth(code)
        oauth_access_token = @oauth.get_access_token(code)
        @graph = Koala::Facebook::API.new(oauth_access_token)
        pages = @graph.get_connections("me", "accounts")
        pages = pages.collect{|p| p  unless p["category"].eql?("Application")}.compact
        eval((@app_type+"_block").upcase).call(pages, oauth_access_token)
      end
      
      def page_tab_add(tabs_added)
        PAGE_TAB_BLOCK.call(tabs_added)
      end

      def profile_name(profile_id, fan_page)
        begin
          rest = Koala::Facebook::API.new(fan_page.access_token)
          user = rest.get_object(profile_id).symbolize_keys
          user_name = user ? "#{user[:first_name]} #{user[:last_name]}" : ""
        rescue Exception => e
          return ""
        end
      end

    end
  end
end
