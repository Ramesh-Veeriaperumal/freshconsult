module OcrHelper
  SERVICE = 'freshdesk'.freeze
  
  def headers
    {
      'Authorization' => "Token #{jwt_token}",
      'Content-Type' => 'application/json'
    }
  end
  
  def jwt_token
    JWT.encode payload, OCR_CONFIG[:jwt_secret], 'HS256', { 'alg' => 'HS256', 'typ' =>'JWT'}
  end

  def payload
    {
      account_id: Account.current.id.to_s,
      service: SERVICE
    }
  end
end
