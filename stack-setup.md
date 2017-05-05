
# Staging Stack setup

##### Enable article publishing
To enable article publishing, make sure the account is verified (accounts table-> reputation column)
And there are 2 redis keys that are necessary for this to work. You can set them in rails console like this.
```ruby
$redis_others.set("ARTICLE_SPAM_REGEX","(gmail|kindle|face.?book|apple|microsoft|google|aol|hotmail|aim|mozilla|quickbooks|norton).*(support|phone|number)")

$redis_others.set("PHONE_NUMBER_SPAM_REGEX", "(1|I)..?8(1|I)8..?85(0|O)..?78(0|O)6|(1|I)..?877..?345..?3847|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?8(0|O)(0|O)..?79(0|O)..?9(1|I)86|(1|I)..?8(0|O)(0|O)..?436..?(0|O)259|(1|I)..?8(0|O)(0|O)..?969..?(1|I)649|(1|I)..?844..?922..?7448|(1|I)..?8(0|O)(0|O)..?75(0|O)..?6584|(1|I)..?8(0|O)(0|O)..?6(0|O)4..?(1|I)88(0|O)|(1|I)..?877..?242..?364(1|I)|(1|I)..?844..?782..?8(0|O)96|(1|I)..?844..?895..?(0|O)4(1|I)(0|O)|(1|I)..?844..?2(0|O)4..?9294|(1|I)..?8(0|O)(0|O)..?2(1|I)3..?2(1|I)7(1|I)|(1|I)..?855..?58(0|O)..?(1|I)8(0|O)8|(1|I)..?877..?424..?6647|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?844..?83(0|O)..?8555|(1|I)..?8(0|O)(0|O)..?6(1|I)(1|I)..?5(0|O)(0|O)7|(1|I)..?8(0|O)(0|O)..?584..?46(1|I)(1|I)|(1|I)..?844..?389..?5696|(1|I)..?844..?483..?(0|O)332|(1|I)..?844..?78(0|O)..?675(1|I)|(1|I)..?8(0|O)(0|O)..?596..?(1|I)(0|O)65|(1|I)..?888..?573..?5222|(1|I)..?855..?4(0|O)9..?(1|I)555|(1|I)..?844..?436..?(1|I)893|(1|I)..?8(0|O)(0|O)..?89(1|I)..?4(0|O)(0|O)8|(1|I)..?855..?662..?4436")
```

##### General SQS related info
Got to make sure all the necessary SQS queues have been created. It is possible to create most of them using rails console.

##### Search - ES V2(Tickets/contacts/tags/solutions ..) setup
Make sure the applicable SQS queue names in `config/sqs.yml`, `config/search/es_v2/config.yml` and `config/shoryuken.yml` match.
##### Search - CountES (Canned Responses, Scenarios) setup
Make sure count v2 host is configured correctly in `config/elasticsearch.yml`

##### Twitter/Facebook Scheduler tasks
Make sure all the databases mentioned in the `config/database.yml` are actually created.
If some of them are just dummy configs, remove those entries. These schedulers do a `run_on_all_slaves`, which tries to connnect to all shards. If one of them fails, the task will abort.

##### Base domain setup
In stack settings, lookout for the keys looking like this:
```json
  "config": {
    "latest_shard": "shard_7",
    "base_domain": {
      "staging": "projectfalcon.io"
    }
  },
```
Set this to the domain that can be associated to the ELB of this stack.

##### Incoming email setup
Make sure all the email related SQS queues have proper names and are created. They look like
`free_customer_email_queue_%{stack_name}` (replace 'free' with 'active' \ 'trial' \ 'default')

##### Falcon related stack settings
For staging and prestaging environments, in stack setting lookout for this key: `ember_frontend_s3`. It has to be set to the S3 bucket's url where the build will uploaded to. It has to be in sync with the Frontend build settings (`config/deploy.js` and `config/stack-settings.js` in **helpkit-ember** repo)

##### Enabling Falcon
At the moment of writing this, the private API can be turned ON only when the launchparty feature :falcon is launched.
```ruby
Account.find(%{id}).launch(:falcon)
```
or
```ruby
Sharding.select_shard_of('%{domain}') do
    Account.find_by_full_domain('%{domain}').launch(:falcon)
end
```

*API is accessible only over HTTPS.*

##### Others things to look into
. . .


##### What to do when the passenger server refuses to start
Try opening the rails console. If there is a problem with the code or missing config files/keys, most of them error out here.
Fix them and try restarting the server. Chances are high that you may need update the recipes or pull the cookbooks.
