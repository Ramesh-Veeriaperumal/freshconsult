class Facebook::Core::Parser

  include Facebook::KoalaWrapper::ExceptionHandler
  attr_accessor :fan_page, :feed, :intial_feed

  def initialize(feed)
    @intial_feed = feed
    @feed = Facebook::Core::Feed.new(feed)
  end

  def parse
    sandbox do
      Account.reset_current_account
      if @feed.entry_changes
        mapping = Social::FacebookPageMapping.find_by_facebook_page_id(@feed.page_id)
        account_id = mapping.account_id if mapping

        Sharding.select_shard_of(account_id) do
          account = Account.find_by_id(account_id)
          return unless account && account.active?
          account.make_current
          @feed.entry_changes.each do |entry_change|
            @feed.entry_change = entry_change

            if @feed.method && @feed.clazz
              #find the page using the global facebookmapping table check this code
              @fan_page = Social::FacebookPage.find_by_page_id(@feed.page_id)
              if @fan_page && @fan_page.account.features?(:facebook_realtime)
                if @fan_page.reauth_required?
                  range_key = (Time.now.to_f*1000).to_i
                  return Facebook::Core::Util.add_to_dynamo_db(@fan_page.page_id, range_key, @intial_feed)
                end

                if  @fan_page.company_or_visitor?                  
                  ("facebook/core/"+"#{@feed.clazz}").camelize.constantize.new(@fan_page).send(@feed.method, @feed)
                end
              end
            end

          end
        end if account_id
      end
    end
  end

end
