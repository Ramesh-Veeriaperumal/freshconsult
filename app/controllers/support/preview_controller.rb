class Support::PreviewController < SupportController
  before_filter :check_privilege
  before_filter :preview_url, :only => :index
  # skip_before_filter :preview_url, if: -> {params[:mint_preview].present? }
  include Redis::RedisKeys
  include Redis::PortalRedis
  include Redis::OthersRedis
  include Portal::PreviewKeyTemplate

  def index
    flash.keep(:error)
    toggle_preview
  end
 
  private

    def toggle_preview 
         if(params[:mint_preview_toggle])
            if params[:classic]
              set_portal_redis_key(old_preview_key,"true",300)
              remove_others_redis_key(mint_preview_key)
              @preview_url = preview_url_path || support_home_url     
            else
              set_others_redis_key(mint_preview_key,"true",300)
              remove_portal_redis_key(old_preview_key)
              @preview_url = mint_enabled_url_path || support_home_url(:mint_preview => 'true');
            end
         elsif params[:mint_preview].present?
               set_others_redis_key(mint_preview_key,"true",300)
               @preview_url = mint_enabled_url_path || support_home_url(:mint_preview => 'true');
         else
               @preview_url = preview_url_path || support_home_url
         end

    end
    
    def mint_enabled_url_path
        preview_url_path << "?mint_preview = 'true'" if preview_url_path
    end

    def preview_url_path 
       get_portal_redis_key(preview_url)
    end

    def preview_url
      PREVIEW_URL % { :account_id => current_account.id, 
                                    :user_id => User.current.id, 
                                    :portal_id => current_portal.id} 
    end

    def old_preview_key
      IS_PREVIEW % { :account_id => current_account.id,:user_id => User.current.id, :portal_id => current_portal.id}
    end

end