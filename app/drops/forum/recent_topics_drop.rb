class Forum::RecentTopicsDrop < BaseDrop
  def initialize(portal)
    @portal = portal
  end
  
  def before_method(num)
    @portal.recent_portal_topics(portal_user, num)
  end
end