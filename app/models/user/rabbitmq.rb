class User < ActiveRecord::Base
  
  def to_rmq_json(keys, action)
    return user_identifiers if destroy_action?(action)
    @rmq_user_details ||= [user_identifiers, user_basic_properties].reduce(&:merge)
    return_specific_keys(@rmq_user_details, keys)
  end
  
  private
    def user_identifiers
      {
        "id"         => id,
        "account_id" => account_id
      }
    end

    def user_basic_properties
      @rmq_user_basic_properties ||= {
        "name"                =>  name,
        "job_title"           =>  job_title,
        "email"               =>  email,
        "mobile"              =>  mobile,
        "phone"               =>  phone,
        "created_at"          =>  created_at,
        "deleted"             =>  deleted,
        "helpdesk_agent"      =>  helpdesk_agent
      }
    end
end