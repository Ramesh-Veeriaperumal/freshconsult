class Social::FacebookStream < Social::Stream
  include Facebook::Constants

  publishable on: [:create, :update], if: :publish_stream?
  after_commit :populate_ticket_rule, on: :create
  before_update :rule_snapshot_before_update
  before_save :persist_previous_changes
  after_update :rule_snapshot_after_update

  private

  def populate_ticket_rule(rule_type = fetch_rule_type)
    return unless can_create_rule?

    params = ticket_rule_params(rule_type)
    facebook_ticket_rules.create(params)
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

  def fetch_rule_type
    if default_stream?
      RULE_TYPE[:optimal]
    elsif dm_stream?
      RULE_TYPE[:dm]
    end
  end

  def persist_previous_changes
    @custom_previous_changes = changes
  end

  def previous_changes
    @custom_previous_changes || HashWithIndifferentAccess.new
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

  def rule_snapshot_before_update
    @model_changes ||= {}
    @model_changes[:rules] = []
    @model_changes[:rules][0] = Account.current.facebook_streams.find_by_id(id).rules
  end

  def rule_snapshot_after_update
    @model_changes[:rules][1] = rules
  end
  
  def group
    facebook_page.product ? facebook_page.product.primary_email_config.group_id : nil
  end

  def publish_stream?
    ad_stream? && Account.current.fb_ad_posts_enabled?
  end
end

