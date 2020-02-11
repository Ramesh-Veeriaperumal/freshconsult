class Collaboration::Article
  TOKEN_EXPIRY_TIME = 1_296_000 # (in sec) 15 DAYS

  def convo_token(article_meta_id, lang_code)
    JWT.encode(convo_payload(article_meta_id, lang_code), CollabConfig['secret_key']) if User.current
  end

  def convo_payload(article_meta_id, lang_code)
    current_user = User.current
    payload = {
      Type: 'article',
      ConvoId: format('%{article_meta_id}-%{lang_code}', article_meta_id: article_meta_id, lang_code: lang_code),
      UserId: current_user.id.to_s,
      exp: (Time.now.to_i + TOKEN_EXPIRY_TIME)
    }
    if freshid_authorization
      uuid = { UserUUID: current_user.freshid_authorization.uid }
      payload.merge!(uuid)
    end
    payload
  end

  private

    def freshid_authorization
      Account.current.freshid_enabled? && User.current.freshid_authorization
    end
end
