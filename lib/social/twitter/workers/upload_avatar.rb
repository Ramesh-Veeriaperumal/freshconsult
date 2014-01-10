class Social::Twitter::Workers::UploadAvatar
  extend Resque::AroundPerform

  @queue = 'upload_avatar_worker'


  def self.perform(args)
    @account = Account.current
    if args[:twitter_handle_id]
      upload_handle_avatar(args)
    elsif args[:twitter_user_id]
      upload_twitter_user_avatar(args)
    end
  end


  def self.upload_handle_avatar(args)
    avatar_sandbox do
      handle = @account.twitter_handles.find(args[:twitter_handle_id])
      wrapper = TwitterWrapper.new handle
      twitter = wrapper.get_twitter
      prof_img_url = twitter.user.profile_image_url
      {:item => handle , :profile_image_url => prof_img_url}
    end
  end

  def self.upload_twitter_user_avatar(args)
    avatar_sandbox do
      user = @account.users.find(args[:twitter_user_id])
      {:item => user, :profile_image_url => args[:prof_img_url]}
    end
  end


  def self.avatar_sandbox
    begin
      hash = yield
      file = RemoteFile.new(hash[:profile_image_url])
      if file
        avatar = hash[:item].build_avatar({:content => file })
        avatar.save
      end
    rescue Exception => e
      puts "Exception in UploadAvatarWorker :: #{e.to_s} :: #{e.backtrace.join("\n")}"
      NewRelic::Agent.notice_error(e.to_s, :custom_params =>
                        {:description => "Exception in UploadAvatarWorker",
                         :params => hash[:item].id})
    ensure
      if file
        file.unlink_open_uri if file.open_uri_path
        file.close
        file.unlink
      end
    end
  end
end
