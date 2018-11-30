module CentralPublisher
  class Worker
    def perform(payload_type, args = {})
      Sharding.run_on_slave do
        super(payload_type, args)
      end
    end
  end
end