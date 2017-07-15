module AgentContactConcern
  extend ActiveSupport::Concern

  def assume_identity
    user = @item.is_a?(User) ? @item : @item.user
    if assume_identity_for_user(user)
      head 204
    else
      render_errors(assume_identity: :not_allowed_to_assume)
    end
  end
end
