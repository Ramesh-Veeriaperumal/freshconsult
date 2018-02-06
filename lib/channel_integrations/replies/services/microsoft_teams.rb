module ChannelIntegrations::Replies::Services
  class MicrosoftTeams
    include ChannelIntegrations::Utils::ActionParser

    def install_app(args)
      # do nothing just acknowledge for now.
    end

    def uninstall_app(args)
      # do nothing just acknowledge for now.
    end

    def authorize_agent(args)
      # do nothing just acknowledge for now.
    end
  end
end
