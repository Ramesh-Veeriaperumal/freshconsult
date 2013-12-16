class Facebook::Core::Feed
  attr_accessor :feed, :entry, :entry_change, :entry_changes, :method, :clazz

  VERB_LIST = ["add"]
  ITEM_LIST = ["status","post","comment"]

  def initialize(feed)
    parse(feed)
  end

  def parse(feed)
    begin
      @feed=JSON.parse(feed)
      #Send the fb realtime data to Splunk for debugging
      Monitoring::RecordMetrics.register(@feed) unless @feed["counter"]
      convert_to_object if @feed
    rescue Exception => e
      Rails.logger.error("Failed in parsing to json")
      NewRelic::Agent.notice_error(e,{
        :description=>"Error while parsing facebook feed to json"
      })
    end
  end

  def entry_change=(change)
    @entry_change = change
    meta_method_and_class if is_feed?
  end

  def page_id
    return @entry["id"].to_s
  end

  def post_id
    return @entry_change["value"]["post_id"].to_s if @entry_change["value"]["post_id"]
  end

  def comment_id
    return @entry_change["value"]["comment_id"].to_s if @entry_change["value"]["comment_id"]
  end

  def parent_id
    return @entry_change["value"]["parent_id"].to_s if @entry_change["value"]["parent_id"]
  end

  #returns a string containing add or remove
  def meta_method_and_class
    verb_data = @entry_change["value"]["verb"].downcase if @entry_change["value"]["verb"]
    @method = VERB_LIST.include?(verb_data) ? verb_data : nil
    meta_class if @method
  end

  #returns a string containing type of feed is either status,post,comment
  def meta_class
    item_data = @entry_change["value"]["item"].downcase if @entry_change["value"]["item"]
    @clazz = ITEM_LIST.include?(item_data) ? item_data : nil
  end

  def is_feed?
    return true if @entry_change && @entry_change["field"]=="feed" && \
      @entry_change["value"]
  end

  private

    def convert_to_object
      @entry = @feed["entry"] if @feed["entry"]
      if @entry
        @entry_changes = @entry["changes"] if @entry["changes"]
        # meta_method_and_class if is_feed?
      end
    end

end
