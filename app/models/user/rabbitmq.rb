class User < ActiveRecord::Base
  
  # Depending on the usecase, additional methods can be
  # added similar to ticket/rabbitmq.rb
  # Currently using only identifiers
  
  def to_rmq_json
    @rmq_user_details ||= user_identifiers
  end
  
  private
    def user_identifiers
      {
        "id"         => id,
        "account_id" => account_id
      }
    end
  
  
end