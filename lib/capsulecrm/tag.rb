class CapsuleCRM::Tag < CapsuleCRM::Base

  attr_accessor :name
  attr_accessor :party_id

  # nodoc
  def self.xml_map
    map = {
      'name' => 'name'
    }
    super.merge map
  end
  
  # nodoc
  def save
    return false if party_id.blank?
    path = "/api/party/#{party_id}/tag/#{name}"
    response = self.class.post(URI.encode(path))
    return self if response.code == 201
    return false
  end
  
end
