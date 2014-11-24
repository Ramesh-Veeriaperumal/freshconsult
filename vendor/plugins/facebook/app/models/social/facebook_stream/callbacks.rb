class Social::FacebookStream < Social::Stream
  
  after_commit_on_create :populate_ticket_rule
    
  private   
  def populate_ticket_rule
    return unless account.features?(:social_revamp)
    ticket_rule = self.ticket_rules.create(
      :filter_data => {
        :includes => [] 
      },
      :action_data => {
        :product_id => facebook_page.product_id,
        :group_id   => group
      })
  end
  
  def group
    facebook_page.product ? facebook_page.product.primary_email_config.group_id : nil
  end
  
end
