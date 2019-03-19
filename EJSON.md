# EJSON as Secure Way of Delivering Application Secrets

Currently the secrets are managed in OpsWorks' Stack Settings JSON. Though this has been the way so far we felt it was deficient for the following reasons.

- Stack setting are plain text and readable from the AWS management console
- Changes to stack settings is difficult to manage and version
- Changes to stack settings changes is difficult trace back to requirements for change
- Difficult to make the application more self contained for the dockerization

To address the above concern we would want to move all templates(ERB's) and app specific configuration element(for ymls), including secrets, as part of the helpkit codebase. And keep the secrets truly secret we have chosen to use [EJSON-wrapper](https://github.com/envato/ejson_wrapper).

## How does EJSON-wrapper work?

[EJSON-wrapper](https://github.com/envato/ejson_wrapper), is extended implementation of [EJSON](https://github.com/Shopify/ejson) that securely ecrypts all the values in JSON(or ejson file), using public key, elliptic curve cryptography (NaCl Box: Curve25519 + Salsa20 + Poly1305-AES), while the private itself encrypted using KMS.

The way EJSON works is, consider you have an ejson(not yet encrypted) like the following. 


```json
{
    "_public_key": "63ccf05a9492e68e12eeb1c705888aebdcc0080af7e594fc402beb24cce9d14f",
    "_private_key_enc": "<encrypted-private-key>",
    "database": {
        "_username": "root",
        "password": "reallystrongpassword"
    }
}
```

This could safely distributed along with your code, by encrypting it using the EJSON, which uses the value of `_public_key` to encryt all values of keys that do not start with `_`(underscrore). And then the ejson file will look like this.

```json
{
    "_public_key": "63ccf05a9492e68e12eeb1c705888aebdcc0080af7e594fc402beb24cce9d14f",
    "_private_key_enc": "<encrypted-private-key>",
    "database": {
        "_username": "root",
        "password": "EJ[1:WGj2t4znULHT1IRveMEdvvNXqZzNBNMsJ5iZVy6Dvxs=:kA6ekF8ViYR5ZLeSmMXWsdLfWr7wn9qS:fcHQtdt6nqcNOXa97/M278RX6w==]"
    }
}
```

And the decryption will happen while generating configs, using the EJSON-wrapper executable which decrypts the `_private_key` using AWS KMS, and use that the private key to decrypt the contents of EJSON.

## Proposal of Usage

[Reference Helpkit Branch](https://github.com/freshdesk/helpkit/tree/yml-config/)

The method that we follow is to move all the YML templates(ERB files) as part of the helpkit codebase, as you would notice on the reference barnch [here](https://github.com/freshdesk/helpkit/tree/yml-config/deploy/config/erb). And keep many of the app specific configs(which includes secrets of some sort), that were originally part of the stack settings, into EJSON's for every pod(US, EUC etc.) and every environment(staging, production etc.), as you could notice [here](https://github.com/freshdesk/helpkit/blob/yml-config/deploy/config/settings-staging-us-east-1.ejson)

So now, the developers needing to introduce new YML, for some requirement, would create a new corresponding ERB file, with necessary placeholders. And then she/he would need to go update the appropriate, keys and values for those placeholders in the EJSON files. 

The developer will need to ensure that she/he follows the rule of EJSON while creating the keys, key names of secrets should NEVER start with an `_`. Its important to note that there will be an EJSON for every POD and every ENVIRONMENT, and also notice the structure of the EJSON file,



- `_public_key`: The public used to encrypt the keys in the EJSON(**NOT to be tampered**)
- `_private_key_enc`: The encrypted private key used to decrypt the keys on server(**NOT to be tampered**)
- `settings`: Indicates the global setting appropriate if no layer settings a provided
- `layer_settings.<layer_name>`: Indicate settings for that particular layer, which will override global `settings` if any
- `settings.ymls`: Indicates global YML settings
- `settings.<layer_name>.ymls`: Indicates the layer specific YML settings overrides global `settings.ymls` if any

Once the developer has done changes, there is a helper [script](https://github.com/freshdesk/helpkit/blob/yml-config/deploy/config/dynamic_config_util.rb) that they could use to encrypt the file, like this.

```
./deploy/config/dynamic_config_util.rb encrypt --file ./deploy/config/settings-staging-us-east-1.ejson
```

Once they done that they could commit the changes to git and send in PR. Note, we have a [precommit hook](https://github.com/freshdesk/helpkit/blob/yml-config/script/githooks/pre-commit), which will `validate` all EJSON files to check no secrets slip through the gaps.

## What are the gains?

- Using the this method of the having configs alongside the code will help config changes to flow along with the respective code changes, rather being tracked as part of recipes changes, enabling better tractability.
- To ensure the secrets are held at one place in a secure manner which also ensure that any tampering could be easily tracked.
- The application will become more self contained, and carried across various environments, and essentially the dockerization will be come much more efficient.

## FAQ

TBD







