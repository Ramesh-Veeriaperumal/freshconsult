module Searchv2
  module SearchHelper

    ES_DELAY_TIME = 3

    def setup_searchv2
      # Searchv2::TestCluster.start
      Sidekiq::Testing.inline!

      @account.send(:enable_searchv2)
    end

    def teardown_searchv2
      @account.send(:disable_searchv2)
      # Searchv2::TestCluster.stop
      Sidekiq::Testing.disable!
    end
  end
end