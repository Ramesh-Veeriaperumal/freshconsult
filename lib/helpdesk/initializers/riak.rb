# load riak yml
# riak.yml consists of following variables
# *pb_port: 10017
# *http_port: 10018
# *node_size: 5
# *port_interval: 10
# *host: 127.0.0.1

# This configuration file is only to defrentiate between development and production
riak_buckets = YAML::load(ERB.new(File.read("#{Rails.root}/config/riak_buckets.yml")).result)
riak_config = YAML::load(ERB.new(File.read("#{Rails.root}/config/riak.yml")).result)

RIAK_BUCKETS = (riak_buckets[Rails.env] || riak_buckets)
RIAK_CONF = (riak_config[Rails.env] || riak_config)

# Intializing the nodes to an empty array
nodes = []

# iterating and constructing each node and inserting into the nodes array
RIAK_CONF.each do |key,value|
	nodes << value.symbolize_keys
end

# request timeout
$riak_client_timeout = 10

# connecting to the riak client with pbc protocol you can even connect with http
$node_client = Riak::Client.new(:nodes => nodes, :protocol => "pbc")

# create various buckets in riak
# ticket_body bucket stores the data of ticket's description and various metadata information
# it is named as t_b(ticket_bodies) because of space constraint
$ticket_body = $node_client.bucket(RIAK_BUCKETS["ticket_body"])

# note_body bucket stores the data of note's description and various metadata information
# it is named as n_b(note_bodies) because of space constraint
$note_body = $node_client.bucket(RIAK_BUCKETS["note_body"])
