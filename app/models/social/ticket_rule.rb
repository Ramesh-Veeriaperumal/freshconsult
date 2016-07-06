class Social::TicketRule < ActiveRecord::Base

  include Facebook::Constants
  
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
    filter_data[:includes] ? filter_data[:includes].join(',') : ""
  end

  def group_id
    action_data[:group_id].to_i
  end

  def product_id(twitter_stream)
    if !twitter_stream.id.nil? and !twitter_stream.twitter_handle.nil?
      new_record? ? twitter_stream.twitter_handle.product_id : action_data[:product_id]
    end
  end
  
  ["strict", "optimal", "broad"].each do |rule_type|
    define_method("#{rule_type}?") do
      filter_data[:rule_type] && (filter_data[:rule_type] == RULE_TYPE[rule_type.to_sym])
    end
  end
  
  def convert_fb_feed_to_ticket?(post, status, visitor_comment, message)
    return false if strict?
          
    if optimal?
      return import_visitor_posts? if post
      
      return apply(message) if (visitor_comment && import_company_comments?)
    end
      
    return post || (status && visitor_comment) if broad?
  end

  def import_visitor_posts?
    optimal? && filter_data[:import_visitor_posts]
  end
  
  def import_company_comments?
    optimal? && filter_data[:import_company_comments]
  end

  private
    def check_includes(social_feed)
      includes = filter_data[:includes]
      includes.each do |keyword|
        to_match = tokenize(keyword)
        #dot removed as it's the generic end of line character
        feed     = "\s#{social_feed.gsub(".","")}\s"
        match_found = to_match.all?{|match| feed.downcase.include?(match.downcase)}
        return true if match_found
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
      keywords.flatten!.map!{|word| "\s#{word}\s"}
      keywords
    end
end
