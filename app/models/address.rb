class Address < ActiveRecord::Base
  include Redis::RedisKeys
  include Redis::OthersRedis

  self.primary_key = :id
  
  belongs_to :addressable, :polymorphic => true
  
  belongs_to :account
  
  validates_presence_of :state, :zip, :first_name, :last_name,:address1, :city, :country
  after_commit :delete_redis_key, on: :update
  def humanize
    "#{first_name} #{last_name} \n#{address1} #{address2} \n#{state} #{city} \n#{country} #{zip}"
  end
  
  
  def self.required_fields
    [:state, :zip, :first_name, :last_name,:address1, :city, :country]
  end

  private
    def delete_redis_key
      remove_others_redis_key(CARD_FAILURE_COUNT % {account_id: account_id})
    end
end