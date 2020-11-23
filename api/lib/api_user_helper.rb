class ApiUserHelper
  class << self
    def avatar_extension_valid?(avatar)
      ext = File.extname(avatar.respond_to?(:original_filename) ? avatar.original_filename : avatar.content_file_name).downcase
      [ContactConstants::AVATAR_EXT.include?(ext), ext]
    end

    def agent_limit_reached?(occasional = false)
      return false if occasional || Account.current.subscription.trial?

      agent_limit = Account.current.subscription.agent_limit
      [Account.current.support_agent_limit_reached?(agent_limit), agent_limit]
    end
  end
end
