module UsageMetrics::GardenFeatures
  include UsageMetrics::BlossomFeatures
  FRESHDESK_USER_EMAIL_REGEX = /.*@freshdesk.com/

  def parent_child_tickets_toggle(args)
    args[:account].has_features? :parent_child_tickets
  end

  def link_tickets_toggle(args)
    args[:account].has_features? :link_tickets
  end

  def ticket_templates(args)
    args[:account].ticket_templates.exists?
  end

  def css_customization(args)
    args[:account].portal_templates.has_custom_css?
  end

  def multi_language(args)
    args[:account].solution_articles.has_multi_language_article?
  end

  def forums(args)
    post = args[:account].posts.order('id desc').first
    post.present? ? FRESHDESK_USER_EMAIL_REGEX.match(post.user.email).nil? : false
  end

  def support_bot(args)
    args[:account].bots.exists?
  end
end