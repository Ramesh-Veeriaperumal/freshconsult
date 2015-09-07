class Doorkeeper::Api::ApiController < ::ApplicationController
  
  private
  
  def current_resource_owner
    @current_resource_owner ||= User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
  end
end
