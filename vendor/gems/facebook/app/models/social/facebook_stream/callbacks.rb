class Social::FacebookStream < Social::Stream
  
  include Facebook::Constants
  
  after_commit :populate_ticket_rule, on: :create,  :if => :facebook_revamp_enabled?
  

  private   

  def populate_ticket_rule(rule_type = default_rule_type)
    return unless can_create_rule?
    
    params  = ticket_rule_params(rule_type)
    self.ticket_rules.create(params)
  end
  
  def can_create_rule?
    can_create_mention_rule? || can_create_dm_rule?
  end
  
  def can_create_mention_rule?
    self.default_stream? && self.facebook_page
  end
  
  def can_create_dm_rule?
    self.dm_stream? && self.facebook_page && self.facebook_page.import_dms
  end
  
  def default_rule_type
    self.default_stream? ? RULE_TYPE[:optimal] : RULE_TYPE[:dm]
  end
  
  def ticket_rule_params(rule_type)
    rule_params = {
      :filter_data => {
        :rule_type => rule_type
      },
      :action_data => {
        :product_id => facebook_page.product_id,
        :group_id   => group
      }
    }
    
    if (rule_type == RULE_TYPE[:optimal])
      rule_params[:filter_data].merge!({
          import_visitor_posts: true,
          import_company_comments: true,
          includes: DEFAULT_KEYWORDS
        }) 
    end
    rule_params
  end
  
  def group
    facebook_page.product ? facebook_page.product.primary_email_config.group_id : nil
  end 

  def facebook_revamp_enabled?
    Account.current.features?(:social_revamp)
  end  
end

