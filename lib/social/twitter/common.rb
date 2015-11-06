module Social::Twitter::Common
  
  def get_twitter_user(screen_name, profile_image_url=nil, user_name=nil)
    account   = Account.current
    user      = account.all_users.find_by_twitter_id(screen_name)
    user_name = screen_name if user_name.to_s.blank?
    
    if user && (user.name != user_name)
      user.update_attributes({:name => user_name})
    elsif user.nil?
      user = account.contacts.new
      user.signup!({
                     :user => {
                       :twitter_id      => screen_name,
                       :name            => user_name.to_s,
                       :active          => true,
                       :helpdesk_agent  => false
                     }
      })
    end
    if user.avatar.nil? && !profile_image_url.nil?
      args = {
        :account_id       => account.id,
        :twitter_user_id  => user.id,
        :prof_img_url     => profile_image_url
      }
      Resque.enqueue(Social::Workers::Twitter::UploadAvatar, args)
    end
    user
  end
end
