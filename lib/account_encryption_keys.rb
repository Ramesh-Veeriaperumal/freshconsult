class AccountEncryptionKeys < Dynamo

  PRIMARY_KEY = :account_id
  PRIMARY_KEY_TYPE = :n
  TABLE_NAME = 'account_encryption_keys_%{environment}'
  
  hash_key(PRIMARY_KEY, PRIMARY_KEY_TYPE)
  provisioned_throughput(1, 1)

  def self.table_name
    TABLE_NAME % { environment: Rails.env[0..3] }
  end

  def self.update account_id, attributes_hash
    CLIENT.update_item update_hash(account_id, attributes_hash)
  rescue Exception => e
    Rails.logger.error "AccountEncryptionKeys::Error while updating in DynamoDB, a=#{account_id}, e=#{e.inspect}"
  end

  def self.find account_id, key_name = nil
    result_hash = CLIENT.get_item query_hash(account_id)
    encryption_key_hash(result_hash, key_name)
  rescue Exception => e
    Rails.logger.error "AccountEncryptionKeys::Error while reading from DynamoDB, a=#{account_id}, key_name=#{key_name.inspect}, e=#{e.inspect}"
  end

  private
  def self.query_hash account_id
    {
      table_name: table_name,
      key: { PRIMARY_KEY.to_s => attr_convert(account_id.to_i) }
    }
  end

  def self.update_hash account_id, attributes_hash
    query_hash(account_id).merge({ attribute_updates: attribute_update_hash(attributes_hash) })
  end

  def self.encryption_key_hash result_hash, key_name
    item = result_hash[:item]
    if key_name.present?
      convert item[key_name.to_s]
    else
      item.delete(PRIMARY_KEY.to_s)
      item.each { |k,v| item[k] = convert v }
      item
    end
  end

  def self.attribute_update_hash(attributes_hash)
    hash = {}
    attributes_hash.each do |key, value|
      hash[key.to_s] = {
        value: attr_convert(value),
        action: DYNAMO_ACTIONS[:put]
      }
    end
    hash
  end

end