class Social::FacebookStream < Social::Stream
  
  include Facebook::Constants
  
  after_commit :populate_ticket_rule, on: :create,  :if => :facebook_revamp_enabled?
  
  def update_ticket_rule
    self.default_stream? ? update_mention_rule : update_dm_rule
  end
    
  private   

  def populate_ticket_rule(rule_type = default_rule_type)
    return unless can_create_rule?
    params = ticket_rule_params(rule_type)
    ticket_rule = self.ticket_rules.create(params)
  end
  
  def update_mention_rule
    tkt_rule_type = if can_create_mention_rule?
      !self.facebook_page.company_or_visitor? ? RULE_TYPE[:strict] : (self.facebook_page.import_only_visitor_posts ? RULE_TYPE[:optimal] : RULE_TYPE[:broad])
    end
    update_rule(tkt_rule_type)
  end
  
  def update_dm_rule
    can_create_dm_rule? ? update_rule(RULE_TYPE[:dm]) : destroy_ticket_rule
  end

  def group
    facebook_page.product ? facebook_page.product.primary_email_config.group_id : nil
  end
  
  def can_create_rule?
    can_create_mention_rule? or can_create_dm_rule?
  end
  
  def can_create_mention_rule?
    default_stream? and self.facebook_page
  end
  
  def can_create_dm_rule?
    dm_stream? and self.facebook_page and self.facebook_page.import_dms
  end
  
  def default_rule_type
    self.default_stream? ? RULE_TYPE[:optimal] : RULE_TYPE[:dm]
  end
  
  def ticket_rule_params(rule_type)
    {
      :filter_data => {
        :rule_type => rule_type
      },
      :action_data => {
        :product_id => facebook_page.product_id,
        :group_id   => group
      }
    }
  end
  
  def update_rule(rule_type)
    ticket_rule = self.ticket_rules.first
    if ticket_rule.present?
      params = ticket_rule_params(rule_type)
      ticket_rule.update_attributes(params)
    else
      populate_ticket_rule(rule_type)
    end
  end
    
  def destroy_ticket_rule
    ticket_rule = self.ticket_rules.first
    ticket_rule.destroy if ticket_rule
  end    

  def facebook_revamp_enabled?
    Account.current.features?(:social_revamp)
  end  
end

