module LinkedAccountsTestHelper
  def link_freshchat
    return @freshchat = @account.freshchat_account if @account.freshchat_account.present?
    @freshchat = @account.build_freshchat_account
    @freshchat.enabled = true
    @freshchat.app_id = 'test'
    @freshchat.save
  end

  def link_freshcaller
    return @freshcaller = @account.freshcaller_account if @account.freshcaller_account.present?
    @freshcaller = @account.build_freshcaller_account
    @freshcaller.freshcaller_account_id = 1
    @freshcaller.domain = 'localhost'
    @freshcaller.save
  end

  def append_header
    request.env['X-Channel-Auth'] = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzb3VyY2UiOiJvY3JfY2hhbm5lbCJ9.r-V5GlxseYtr0izF9epaTRGBi69IP7ZLMbw0A8Tny-g'
    request.env['CONTENT_TYPE'] = 'application/json'
  end

  def remove_freshchat
    @account.freshchat_account.enabled = false
    @account.freshchat_account.destroy
  end

  def remove_freshcaller
    @account.freshcaller_account.destroy
  end
end
