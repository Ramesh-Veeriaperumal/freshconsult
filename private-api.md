IMPORTANT: Just because this is private api, **does not mean** our customers cannot consume it. "Private" here means, we are not liable if something that they setup broke because we change the private api.
It is meant for clients (like the Ember based Falcon UI) built by Freshdesk.

# Private API - Design & Development Guidelines

Private API inherits from API v2. And most of the guidelines will be followed here as well.
Things that are different from API v2 are documented here.
[API V2 Design and Development](https://docs.google.com/document/d/13VuvUZpAJXcDtx_jZLo93xZiggoWxJFebYdi_1ZK4LE/edit)

### Setup
**config/infra_layer.yml**

Set `API_LAYER` to `true`

SET `PRIVATE_API` to `true`

The private API can be turned ON only when the launchparty feature :falcon is launched.

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


### Routing
URL namespace: `/api/_/`
Route file used: `config/api_routes.rb`
Private API has its own set of routes overriding many of the routes from API V2, introducing new ones and still allowing to fallback to API v2 in some instances.

Routes for this are supposed to be written only inside this block:
```ruby
ember_routes = proc do
...
end
```

### Privileges
Whenever you are introducing a new route/controller/action, please make sure you add the appropriate privileges in `config/api_privileges.rb`
We dont always have to copy the privileges set in the legacy `config/privileges.rb`.

*For eg. `ticket_fields` or `email_configs` routes require only `manage_tickets` privilege in the API context, while they would require `admin_tasks` or similar high privileges in the legacy app.*

### API Design
For design guidelines, please check out [this doc](https://docs.google.com/document/d/14KLjrI2exTxM0mLn0oeTW5SoYlzH3xKpmksmAdgkRwU/edit#)
There are some parts where we have set new standards for Private API.
- All the responses will have a root element
  - The root element is automatically taken from the Controller name. *Checkout `lib/middleware/api_response_wrapper.rb`*
  - It can be overwritten when you override for the `SINGULAR_RESPONSE_FOR`, `COLLECTION_RESPONSE_FOR`, `ROOT_KEY` constants.
  - For a few use cases, wherein we cannot generalize the root node for the entire controller, we can set `response.api_root_key` directly.
- Still no root node for the request body.
- No rate limiting. This is a temporary thing. We will re-introduce rate-limiting one we've figured out the ideal limits for UI consumption.
- Please try to stick to general REST API standards possible.
- Include `helper_concern.rb` in the controllers to avoid redundant code for instantiating delegators, validation classes etc. Override its methods where necessary. For usage, refer other controllers in `api/app/controllers/ember` folder that included this concern.

### View files
- We prefer that most of the view presentation logic for each model is abstracted inside decorators for those models.
- The name of the decorators need not be the same as the model; it is expected to be the same as root node of the model in the API response. *Eg: `ConversationDecorator` is the one being used for all the `Helpdesk::Note` objects.*
- Jbuilder is not used. Please use only .json.api files
- View files are expected to be really simple, wherein they just call to_hash or similar methods from the instance(s) of the decorator object(s).

### Review
Before creating a PR or sending it for review, make sure:
- Validation classes are for static data-type like validations. Do not involve data-sanity or association or any DB heavy stuff in here.
- Delegators are meant to ensure the data sanity before we hit the model's validation or transaction.
- Swagger docs are written (Checkout swagger.md). Also make sure the generated swagger.json is valid.
- Rubocop is ran on all the files created/modified. It is even nicer, if you can keep the flog scores in check as well.
- Tests for the modifications are written and the coverage verified.
- Only squash commits. Lets minimize the merge commits and lets resolve all the conflicts in our local branches.

#### Pull Requests
- Raise PRs against `falcon-prestaging` branch
- Your branch name to start with `falcon-%{feature-name}`
- Make sure the branch is deleted once the PR is merged.

