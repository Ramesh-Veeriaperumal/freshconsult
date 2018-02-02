module ChannelIntegrations::Replies::Services
  class GoogleHangoutChat
    include ChannelIntegrations::Utils::ActionParser

    def install_app(args)
      # do nothing just acknowledge for now.
    end

    def uninstall_app(args)
      # do nothing just acknowledge for now.
    end
  end
end