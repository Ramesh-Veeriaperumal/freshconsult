class Social::FacebookStream < Social::Stream
  
  include Facebook::Constants
  
  concerned_with :callbacks
  
  belongs_to :facebook_page,
    :foreign_key => :social_id,
    :class_name  => 'Social::FacebookPage'

    
  def replies_enabled?
    self.data[:replies_enabled]
  end
  
  def import_visitor_posts?
     default_stream? and self.facebook_page and self.facebook_page.import_visitor_posts
  end

  def import_company_posts?
    default_stream? and self.facebook_page and self.facebook_page.import_company_posts
  end

  def default_stream?
    self.data[:kind] == FB_STREAM_TYPE[:default]
  end
  
  def dm_stream?
    self.data[:kind] == FB_STREAM_TYPE[:dm]
  end
  
  def check_ticket_rules(feed, allow_empty_rule = false)
    hash = {
      :stream_id => self.id,
      :convert   => false
    }
    tkt_rules = self.ticket_rules
    tkt_rules.each do |rule|
      if rule.apply(feed, allow_empty_rule)
        hash.merge!({
          :convert    => true,
          :group_id   => rule.action_data[:group_id],
          :product_id => rule.action_data[:product_id]
        })
        break
      end
    end
    hash
  end

end
