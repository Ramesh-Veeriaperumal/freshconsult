module Portal::PreviewKeyTemplate
	 def mint_preview_key
       if User.current
       		MINT_PREVIEW_KEY % { :account_id => current_account.id, 
                       :user_id => User.current.id, :portal_id => current_portal.id}
    	end
     end
     
      def on_mint_preview
     	get_others_redis_key(mint_preview_key)
     end
end