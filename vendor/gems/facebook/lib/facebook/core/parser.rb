class Facebook::Core::Parser

  include Facebook::KoalaWrapper::ExceptionHandler
  include Social::Constants
  include Facebook::Core::Util
  include Facebook::Constants
  
  
  attr_accessor :fan_page, :feed, :intial_feed

  def initialize(feed)
    @intial_feed = feed
    @feed = Facebook::Core::Feed.new(feed)
  end

  def parse
    Account.reset_current_account
    if @feed.entry_changes
      mapping = Social::FacebookPageMapping.find_by_facebook_page_id(@feed.page_id)
      account_id = mapping.account_id if mapping

      Sharding.select_shard_of(account_id) do
        sandbox do
          account  = Account.find_by_id(account_id)
          return unless account && account.active?
          account.make_current

          @feed.entry_changes.each do |change|
            @feed.entry_change = change

            if @feed.method && @feed.clazz
              @fan_page = Social::FacebookPage.find_by_page_id(@feed.page_id)
              if @fan_page && @fan_page.account.features?(:facebook_realtime)
                if @fan_page.reauth_required?
              #find the page using the global facebookmapping table check this code
                  range_key = (Time.now.to_f*1000).to_i
                  return Facebook::Core::Util.add_to_dynamo_db(@fan_page.page_id, range_key, @intial_feed)
                end
                
                unless feed_converted?(@feed.feed_id)
                  clazz = (@feed.clazz == POST_TYPE[:status]) ? POST_TYPE[:post] : @feed.clazz
                  @koala_feed = ("facebook/koala_wrapper/"+"#{clazz}").camelize.constantize.new(@fan_page)
                  @koala_feed.fetch(@feed.feed_id)
                  @fan_page.update_attribute(:last_error, nil) unless @fan_page.last_error.nil?
                  
                  @feed.clazz = @koala_feed.parent.nil? ? POST_TYPE[:comment] : POST_TYPE[:reply_to_comment] if @feed.clazz == POST_TYPE[:comment]
                  ("facebook/core/"+"#{@feed.clazz}").camelize.constantize.new(@fan_page, @koala_feed).send(@feed.method, @feed)
                end
                
              end
            end
          end
        end
      end if account_id
    end
  end

end
