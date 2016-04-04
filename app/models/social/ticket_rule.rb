class Social::TicketRule < ActiveRecord::Base

  self.table_name =  "social_ticket_rules"
  self.primary_key = :id

  belongs_to_account

  belongs_to :stream,
    :foreign_key => :stream_id,
    :class_name => 'Social::Stream'

  serialize :filter_data, Hash
  serialize :action_data, Hash

  attr_accessible :filter_data, :action_data, :position
  acts_as_list :scope => :stream


  def apply(feed)
    #For now, check for includes alone
    return check_includes(feed)
  end

  def include_keys
    filter_data[:includes].join(',')
  end

  def group_id
    action_data[:group_id].to_i
  end

  def product_id(twitter_stream)
    if !twitter_stream.id.nil? and !twitter_stream.twitter_handle.nil?
      new_record? ? twitter_stream.twitter_handle.product_id : action_data[:product_id]
    end
  end

  private
    def check_includes(feed)
      includes = filter_data[:includes]
      includes.each do |keyword|
        to_match = tokenize(keyword)
        match_found = to_match.each.map{|match| feed.downcase.include?(match.strip.downcase)}
        return true unless match_found.include?(false)
      end
      return false
    end

    def tokenize(str)
      str_array = str.split("")
      keys = []
      keywords = []
      str_array.each do |s|
        if s == "\""
          keywords << keys.join().strip unless keys.blank?
          keys = []
        else
          keys << s
        end
      end
      keywords << keys.join().split(" ")
      keywords.flatten!
      keywords
    end
end
