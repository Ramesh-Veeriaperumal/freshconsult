module Gnip

  module Constants

    SOURCE = {
      :twitter  => "Twitter",
      :facebook => "Facebook"
    }

    DELIMITER = {
      :tags => ":",
      :tag_elements => "_",
      :production_stream => "\r\n",
      :replay_stream => "\r\n\r\n"
    }

    RULE_ACTION = {
      :update => {
        :success => true,
        :failure => false
      },
      :add => "add",
      :delete => "delete"
    }

    RULE_OPERATOR = {
      :and => " AND ",
      :or => " OR ",
      :neg => " -",
      :from => "from",
      :ignore_rt => " -is:retweet"
    }

    STREAM = {
      :replay => "replay",
      :production => "production"
    }

    # time in sec
    REPLAY_STREAM_TIMEOUT = 60

  end

end
