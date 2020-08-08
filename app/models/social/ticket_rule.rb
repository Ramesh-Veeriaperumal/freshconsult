class Social::TicketRule < ActiveRecord::Base
  concerned_with :presenter
  include Social::Constants
  include Facebook::Constants

  self.table_name =  "social_ticket_rules"
  self.primary_key = :id

  belongs_to_account

  belongs_to :stream,
    :foreign_key => :stream_id,
    :class_name => 'Social::Stream'

  serialize :filter_data, Hash
  serialize :action_data, Hash

  after_commit :set_fb_page_reauth_required_if_ad_post_enabled, on: :create, if: -> { account.fb_ad_posts_enabled? }
  attr_accessible :filter_data, :action_data, :position, :rule_type
  acts_as_list :scope => :stream

  def apply(feed, source = SOURCE[:twitter])
    return true if (filter_data[:includes].blank? && source == SOURCE[:facebook])
    return check_includes(feed)
  end

  def include_keys
    filter_data[:includes] ? filter_data[:includes].join(',') : ""
  end

  def group_id
    grp_id = action_data[:group_id].to_i
    grp_id == 0 ? nil : grp_id
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

  #is_a_post - If the current object is a post
  #parent_is_a_status - The parent of the current object is a status
  #is_a_visitor_comment - If the current object is a visitor comment
  #feed_body - Current comment's feed body
  #skip_optimal - Skip the optimal rule evaluation(In case of comments & optimal we are skipping, refer: FD-16831)
  def convert_fb_feed_to_ticket?(is_a_post, parent_is_a_status = false, is_a_visitor_comment = false, feed_body = '', skip_optimal = false, cover_photo_comment = false)
    return false if strict?

    if optimal?
      return false if skip_optimal

      return apply(feed_body, SOURCE[:facebook]) if is_a_visitor_comment && cover_photo_comment && import_company_comments?

      return import_visitor_posts? if is_a_post

      return apply(feed_body, SOURCE[:facebook]) if (is_a_visitor_comment && parent_is_a_status && import_company_comments?)
    end

    return is_a_post || (parent_is_a_status && is_a_visitor_comment) if broad?
  end

  def import_visitor_posts?
    optimal? && filter_data[:import_visitor_posts]
  end

  def import_company_comments?
    optimal? && filter_data[:import_company_comments]
  end

  def filter_mentions?
    filter_data[:filter_mentions]
  end

  def type
    stream.data.try(:[], :kind)
  end

  def set_fb_page_reauth_required_if_ad_post_enabled
    stream.facebook_page.set_reauth_required if filter_data[:rule_type] == RULE_TYPE[:ad_post]
  end
  private
    def check_includes(social_feed)
      includes = filter_data[:includes]
      includes.each do |keyword|
        to_match = tokenize(keyword)
        #dot removed as it's the generic end of line character
        feed     = "\s#{social_feed.gsub(WHITELISTED_SPECIAL_CHARS_REGEX," ")}\s"
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
      keywords.flatten!.map!{ |word|
        word.starts_with?(TWITTER_MENTION) ? "#{word}" : "\s#{word}\s"
      }
      keywords
    end

end
