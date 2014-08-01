module VA::RandomCase
  module Performer

    def define_options
      @options = {
        :agent    => { :type => '1', :result => { @requester => false, @responder => true, @agent2 => true, @agent3 => true } },
        :customer => { :type => '2', :result => { @requester => true, @responder => false, @agent2 => false, @agent3 => false } },
        :anyone   => { :type => '3', :result => { @requester => true, @responder => true, @agent2 => true, @agent3 => true } },
        :specific_agent => { :type => '1', :members => [@agent3.id], :result => { @requester => false, @responder => false, @agent2 => false, @agent3 => true } },
        :assigned_agent => { :type => '1', :members => [-1], :result => { @requester => false, @responder => true, @agent2 => false, @agent3 => false } }
      }
      @option_exceptions = {}
    end

  end
end