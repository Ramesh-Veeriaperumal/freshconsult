class Social::TwitterStream < Social::Stream

  concerned_with :callbacks

  belongs_to :twitter_handle,
    :foreign_key => :social_id,
    :class_name => 'Social::TwitterHandle'


  def check_ticket_rules(tweet_body)
    hash = {:stream_id => self.id}
    tkt_rules = self.ticket_rules
    tkt_rules.each do |rule|
      if rule.apply(tweet_body)
        hash.merge!({
          :convert => true,
          :group_id => rule.action_data[:group_id],
          :product_id => rule.action_data[:product_id]
        })
      end
    end
    return hash
  end
  
  def populate_ticket_rule(includes)
    return unless can_create_rule?
    ticket_rule = self.ticket_rules.create(
      :rule_type => TICKET_RULE_TYPE_KEYS_BY_TOKEN[:custom],
      :filter_data => {
        :includes => includes
      },
      :action_data => {
        :product_id => twitter_handle.product_id,
        :group_id => ( twitter_handle.product ? twitter_handle.product.primary_email_config.group_id : nil )
      })
  end
  
  
  private
    
    def can_create_rule?
      self.twitter_handle.capture_mention_as_ticket if self.twitter_handle
    end

end
