module Faye
  module AutoRefresh

    def self.channel(account)
      "/#{account.full_domain}/#{NodeConfig["auto_refresh_channel"]}"
    end

  end
end
