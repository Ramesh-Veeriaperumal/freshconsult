require 'ansi'

module Searchv2
  module TestCluster

    CLUSTER_DEFAULTS = {
      cluster_name:   "elasticsearch-test-#{Socket.gethostname.downcase}",
      node_name:      "test-node-#{Socket.gethostname.downcase}",
      port:           9090
    }

    def start
      print("\n...Starting elasticsearch test cluster...".ansi(:bold, :cyan))

      unless running?
        command = <<-COMMAND
          #{Rails.root}/test_es/bin/elasticsearch \
            -D es.foreground=yes \
            -D es.cluster.name=#{CLUSTER_DEFAULTS[:cluster_name]} \
            -D es.node.name=#{CLUSTER_DEFAULTS[:node_name]} \
            -D es.http.port=#{CLUSTER_DEFAULTS[:port]} \
            -D es.cluster.routing.allocation.disk.threshold_enabled=false \
            -D es.network.host=localhost \
            -D es.script.inline=on \
            -D es.script.indexed=on \
            -D es.node.test=true \
            -D es.node.testattr=test \
            -D es.node.bench=true \
            -D es.logger.level=DEBUG \
            > /dev/null
        COMMAND

        pid = Process.spawn(command)
        Process.detach(pid)

        until running?
          sleep 1
        end
      else
        print("\nNote: ES for test is already running".ansi(:faint))
      end
    end

    def stop
      print("\n...Stopping elasticsearch test cluster...".ansi(:bold, :cyan))

      if running?
        begin
          nodes = JSON.parse(RestClient.get("localhost:#{CLUSTER_DEFAULTS[:port]}/_nodes/process"))
          pids  = nodes['nodes'].map { |id, info| info['process']['id'] }

          unless pids.empty?
            pids.each_with_index do |pid, i|
              begin
                Process.kill('INT', pid)
              rescue Exception => e
                print("\n[#{e.class}] PID #{pid} not found.")
              end
            end
          end
        rescue
          print("\nFailed to stop elasticsearch for test!!".ansi(:red))
        end
      else
        print("\nNote: ES for test is already halted".ansi(:faint))
      end
    end

    def running?
      RestClient.head("localhost:#{CLUSTER_DEFAULTS[:port]}", content_type: 'application/json').blank? rescue false #=> No response body
    end

    module_function :start, :stop, :running?

  end
end