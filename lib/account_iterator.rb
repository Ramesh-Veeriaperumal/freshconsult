module AccountIterator
  def self.each(args = {}, &block)
    failed_accounts = []
    Account.select(args[:select]).includes(args[:includes]).where(args[:conditions]).joins(args[:joins]).group(args[:group_by]).having(args[:having]).find_in_batches(
      batch_size: (args[:batch_size] || 300)
    ) do |accounts|
      accounts.each do |account|
        account.make_current
        if args[:exception] == false
          block.call(account)
        else
          begin
            block.call(account)
          rescue StandardError => e
            failed_accounts << "#{account.id} => #{e.message}"
          end
        end
      end
      Account.reset_current_account
    end
    puts failed_accounts.inspect unless failed_accounts.empty?
  end
end
