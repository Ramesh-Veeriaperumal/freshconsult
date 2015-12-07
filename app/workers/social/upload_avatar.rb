module Social
  class UploadAvatar < BaseWorker
    
    sidekiq_options :queue => :upload_avatar_worker, :retry => 0, :backtrace => true, :failures => :exhausted
      
    def perform(args)
      if args['twitter_handle_id']
        upload_handle_avatar(args)
      elsif args['twitter_user_id']
        upload_twitter_user_avatar(args)
      end
    end

    def upload_handle_avatar(args)
      avatar_sandbox do
        account = Account.current
        handle  = account.twitter_handles.find(args['twitter_handle_id'])
        wrapper = TwitterWrapper.new handle
        twitter = wrapper.get_twitter
        prof_img_url = twitter.user.profile_image_url.to_s
        {:item => handle , :profile_image_url => prof_img_url}
      end
    end

    def upload_twitter_user_avatar(args)
      avatar_sandbox do
        account = Account.current
        user = account.users.find(args['twitter_user_id'], :select => "id")
        {:item => user, :profile_image_url => args['prof_img_url']}
      end
    end

    def avatar_sandbox
      begin
        hash = yield
        file = RemoteFile.new(hash[:profile_image_url])
        if file
          avatar = hash[:item].build_avatar({:content => file })
          avatar.save
        end
      rescue Exception => e
        Rails.logger.debug "Exception in UploadAvatarWorker :: #{e.to_s} :: #{e.backtrace.join("\n")}"
        custom_params = {
          :description => "Exception in UploadAvatarWorker",
          :params => hash[:item].id
        }
        NewRelic::Agent.notice_error(e.to_s, :custom_params => custom_params)
      ensure
        if file
          file.unlink_open_uri if file.open_uri_path
          file.close
          file.unlink
        end
      end
    end
    
  end
end
