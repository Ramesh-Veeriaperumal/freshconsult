class Omni::SyncFactory
  def self.fetch_bc_sync(args)
    raise 'channel info unavailable in args' if args[:channel].nil?

    "Omni::#{args[:channel].classify}BcSync".constantize.new(args)
  end
end
