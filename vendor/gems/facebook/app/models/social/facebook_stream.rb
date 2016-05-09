class Social::FacebookStream < Social::Stream
  
  include Facebook::Constants
  
  concerned_with :callbacks
  
  belongs_to :facebook_page,
    :foreign_key => :social_id,
    :class_name  => 'Social::FacebookPage'

  def default_stream?
    self.data[:kind] == FB_STREAM_TYPE[:default]
  end
  
  def dm_stream?
    self.data[:kind] == FB_STREAM_TYPE[:dm]
  end
  
  def group(group_id = 0)
    group_id = (group_id == 0 ? nil : group_id)
    group_id = group_id || (facebook_page.product ? facebook_page.product.primary_email_config.try(:group_id) : nil )
  end
  
end
