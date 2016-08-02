class ApiUserHelper
  class << self
    def avatar_extension_valid?(avatar)
      ext = File.extname(avatar.original_filename).downcase
      [ContactConstants::AVATAR_EXT.include?(ext), ext]
    end

    def agent_limit_reached?(occasional = false)
      return false if occasional
      agent_limit = Account.current.subscription.agent_limit
      [Account.current.agent_limit_reached?(agent_limit), agent_limit]
    end
  end
end
