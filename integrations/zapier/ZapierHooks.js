"use strict";
 
//Following code is used in Zapier.com and not in helpkit .
//This is a backup of the version hosted on Zapier.com
//-- Hrishikesh 

var Zap = {
    new_ticket_poller_trigger_post_poll: function (bundle) {
        var responseObj = z.JSON.parse(bundle.response.content);
        if (responseObj.require_login) {
            throw new ErrorException("Your login credentials did not work!");
        }
        return responseObj;
    },

    sanitise_newline_char: function(bundle_request_data) {
        // replacing escaped newline char. with break tag
        return bundle_request_data.replace(/\\n/g, "<br/>");
    },

    get_forum_categories_trigger_post_poll: function (bundle) {
        /**
         * Modified as-per API V2 req. format
         * @param array newResponse
         */
        var newResponse = [],
            responseObj = z.JSON.parse(bundle.response.content);
        responseObj.forEach(function (forumCategory) {
            newResponse.push({
                forum_category: forumCategory
            });
        });
        return newResponse;
    },

    generateJWT: function (bundle) {
        var crypto = require("crypto");
        var currentTime = new Date().toISOString();
        var api_key = bundle.auth_fields.api_key;
        var domain_name = bundle.auth_fields.domain_name;
        // actual keys masked for helpkit copy xxxxxxxxxxxxxxxx
        // make sure to update keys while comitting to zapier
        var jwt_secret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
        var ENCRYPTION_KEY = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
        var IV = "xxxxxxxxxxxxxxxx";

        function encryptPayload(val) {
            // encrypting jwt payload as jwe implementation not possible out of the box in zapier
            // tokens being added only to create tickets/contacts/companies action
            var cipher = crypto.createCipheriv("aes-256-cbc", ENCRYPTION_KEY, IV);
            var encrypted = cipher.update(val, "utf8", "base64");
            encrypted += cipher.final("base64");
            return encrypted;
        }

        //      function decrypt(encryptPayload){
        //        var decipher = crypto.createDecipheriv("aes-256-cbc", ENCRYPTION_KEY, IV);
        //        var decrypted = decipher.update(encryptPayload, "base64", "utf8");
        //        return (decrypted + decipher.final("utf8"));
        //     }

        var base64Header = btoa(JSON.stringify({
            alg: "HS256",
            typ: "JWT",
            source: "zapier"
        }));

        var payload = JSON.stringify({
            domain_name: domain_name,
            timestamp: currentTime
        });

        var encryptedPayload = JSON.stringify({
            "enc_payload": encryptPayload(payload)
        });

        var base64Payload = btoa(encryptedPayload);
        var encryptedData = base64Header + "." + base64Payload;
        var hmac_hash = z.hmac("sha256", jwt_secret, encryptedData, "base64");
        return encryptedData + "." + hmac_hash;
    },

    create_ticket_action_pre_write: function (bundle) {

        var jwtToken = this.generateJWT(bundle);
        bundle.request.headers["X-Channel-Auth"] = jwtToken;

        /**
         * Modified as-per API V2 req. format
         * @param array cc_emails
         * @param integer priority
         * @param dictionary custom_fields
         *  -defaults to medium priority(2) if not set by user
         * @param integer status
         *  -defaults to open status(2)
         */
        bundle.request.data = this.sanitise_newline_char(bundle.request.data);
        var helpdesk_ticket = z.JSON.parse(bundle.request.data),
            cc_emails_array = [];
        if (helpdesk_ticket.cc_emails) {
            cc_emails_array = helpdesk_ticket.cc_emails.split(",");
        }
        helpdesk_ticket = helpdesk_ticket.helpdesk_ticket;

        // truncating subject to API v2 spec. limit of 255
        if (helpdesk_ticket.subject.length > 255) {
            helpdesk_ticket.subject = helpdesk_ticket.subject.substring(0, 252) + '...';
        }

        if (helpdesk_ticket.priority) {
            helpdesk_ticket.priority = parseInt(helpdesk_ticket.priority, 10);
        } else {
            helpdesk_ticket.priority = 2;
        }
        helpdesk_ticket.custom_fields = helpdesk_ticket.custom_field;
        console.log(helpdesk_ticket.custom_fields);

        // this is needed because of v1 -> v2 migration
        delete helpdesk_ticket.custom_field;
        helpdesk_ticket.status = 2;
        helpdesk_ticket.cc_emails = cc_emails_array;


        /**
         * fix for removing acc_id suffixed custom field names coming from old zaps
         * Cases handled :
         * * multiple cf with same `_[0-9]` suffix => suffix is stripped
         * * multiple cf with different `_[0-9]` suffix => nothing is stripped
         * * single cf with `_[0-9]` suffix => suffix stripped
         * * NOTE: we're only renaming keys, not values (for v2 api compatibility)
         */
         
        if (helpdesk_ticket.custom_fields) {
        var cfCount = Object.keys(helpdesk_ticket.custom_fields).length;

        if (cfCount) {
          var cfEndingWithId = 0;
          var accIdSuffix = Object.keys(helpdesk_ticket.custom_fields)[0].match(/_[0-9]+$/g);
          if (accIdSuffix) {
            accIdSuffix = accIdSuffix[0];
            Object.keys(helpdesk_ticket.custom_fields).forEach(function(key) {
              if (key.match(accIdSuffix)) cfEndingWithId++;
            });
          }
          if (cfCount === cfEndingWithId) {
            var customFieldClone = new Object();
            console.log("applying stripped data");
            Object.keys(helpdesk_ticket.custom_fields).forEach(function (key) {
              var newKey = key.replace(/_[0-9]+$/, "");
              customFieldClone[newKey] = helpdesk_ticket.custom_fields[key];
            });
            helpdesk_ticket.custom_fields = customFieldClone;
          }
        }
        }


        bundle.request.data = JSON.stringify(helpdesk_ticket);
        return bundle.request;
    },

    create_forum_category_action_pre_write: function (bundle) {
        /**
         * Modified as-per API V2 req. format
         */
        var forum_category = (z.JSON.parse(bundle.request.data)).forum_category;
        bundle.request.data = JSON.stringify(forum_category);
        return bundle.request;
    },

    create_forum_action_pre_write: function (bundle) {
        /**
         * Modified as-per API V2 req. format
         * @param integer forum_type
         */
        var forum = (z.JSON.parse(bundle.request.data)).forum;
        forum.forum_type = parseInt(forum.forum_type, 10);
        bundle.request.data = JSON.stringify(forum);
        return bundle.request;
    },

    create_user_action_pre_write: function (bundle) {

        var jwtToken = this.generateJWT(bundle);
        bundle.request.headers["X-Channel-Auth"] = jwtToken;

        /**
         * Modified as-per API V2 req. format
         * @param array tags
         */
        var user = (z.JSON.parse(bundle.request.data)).user;
        if (user.tags) {
            user.tags = user.tags.split(",");
        }
        bundle.request.data = JSON.stringify(user);
        return bundle.request;
    },

    create_company_action_pre_write: function (bundle) {

        var jwtToken = this.generateJWT(bundle);
        bundle.request.headers["X-Channel-Auth"] = jwtToken;

        /**
         * Modified as-per API V2 req. format
         * @param array domains
         */
        var customer = (z.JSON.parse(bundle.request.data)).customer;
        if (customer.domains) {
            customer.domains = customer.domains.split(",");
        }
        bundle.request.data = JSON.stringify(customer);
        return bundle.request;
    },

    add_notes_to_ticket_action_pre_write: function (bundle) {
        /**
         * Modified as-per API V2 req. format
         * @param bool incoming
         *  -set to true if a particular conversation should appear as being created from outside of freshdesk app
         */
        bundle.request.data = this.sanitise_newline_char(bundle.request.data);
        var helpdesk_note = (z.JSON.parse(bundle.request.data)).helpdesk_note;
        helpdesk_note.incoming = true;
        bundle.request.data = JSON.stringify(helpdesk_note);
        return bundle.request;
    },
    create_forum_topic_action_pre_write: function (bundle) {
        /**
         * Modified as-per API V2 req. format
         * @param bool sticky
         * @param bool locked
         * @param string message
         */
        var topic = (z.JSON.parse(bundle.request.data)).topic;

        if (topic.sticky && topic.sticky.toString().toUpperCase() == "YES")
            topic.sticky = true;
        else
            topic.sticky = false;
        if (topic.locked && topic.locked.toString().toUpperCase() == "YES")
            topic.locked = true;
        else
            topic.locked = false;

        topic.message = topic.body_html;
        delete topic.body_html;
        bundle.request.data = JSON.stringify(topic);
        return bundle.request;
    },
    getUtils: function () {
        var field_type_map = [];
        field_type_map.custom_paragraph = "text";
        field_type_map.custom_text = "unicode";
        field_type_map.custom_number = "int";
        field_type_map.custom_checkbox = "bool";
        field_type_map.custom_dropdown = "unicode";
        var utils = {};
        utils.translate_field_type = function (fd_field_type) {
            var zap_field_type = "unknown";
            if (fd_field_type.search("custom") != -1)
                zap_field_type = "unicode";
            if (field_type_map[fd_field_type])
                zap_field_type = field_type_map[fd_field_type];

            return zap_field_type;
        };
        utils.get_custom_field_label = function (field) {
            if (field.visible_in_portal)
                return field.label_in_portal;
            else
                return field.label;
        };
        utils.get_field_key = function (field_name, field_type, zap_type) {
            if (field_type.search("custom") != -1) {
                if (zap_type == "trigger") {
                    return field_name.replace(/_[0-9]+$/, "");
                } else {
                    return "helpdesk_ticket__custom_field__" + field_name;
                }
            } else {
                if (zap_type == "trigger") {
                    return field_name;
                } else {
                    return "helpdesk_ticket__" + field_name;
                }
            }
        };
        return utils;
    },

    new_ticket_trigger_post_custom_trigger_fields: function (bundle) {
        console.log("Called processing");
        return this.process_custom_fields(bundle, "trigger");
    },
    ticket_updated_trigger_post_custom_trigger_fields: function (bundle) {
        console.log("Called processing");
        return this.process_custom_fields(bundle, "trigger");
    },
    create_ticket_action_post_custom_action_fields: function (bundle) {
        console.log("Called custom fields processing");
        return this.process_custom_fields(bundle, "action");
    },
    process_custom_fields: function (bundle, zap_type) {
        /**
         * Modified as-per API V2 req. format
         */
        var utils = this.getUtils(),
            customfields = [],
            customfields_input = [],
            ticketFieldArray = z.JSON.parse(bundle.response.content);
        ticketFieldArray.forEach(function (ticketField) {
            ticketField.field_type = ticketField.type;
            delete ticketField.type;
            customfields_input.push({
                ticket_field: ticketField
            });
        });

        if (customfields_input.access_denied) {
            throw new HaltedException("Access is denied. Please check your authentication details");
        }

        customfields = _.map(customfields_input, function (cField) {
            cField = cField.ticket_field;

            var fieldType = cField.field_type;
            var choices = null;
            if (fieldType == "custom_dropdown") {
                choices = [];
                cField.choices.forEach(function (val) {
                      choices.push(val);
                });
            }
            return {
                type: utils.translate_field_type(fieldType),
                key: utils.get_field_key(cField.name, fieldType, zap_type),
                label: utils.get_custom_field_label(cField),
                help_text: cField.description,
                required: false,
                choices: choices
            };
        });

        customfields = _.filter(customfields, function (field) {
            return field.type != "unknown";
        });
        return customfields;
    },
    get_event_data: function (event_name, trigger_fields) {
        console.log("event_name " + event_name);
        var name = "",
            value = "";
        if (event_name == "new_ticket") {
            name = "ticket_action";
            value = "create";
        }
        if (event_name == "update_ticket") {
            name = "ticket_action";
            value = "update";
        }
        if (event_name == "new_user") {
            name = "user_action";
            value = "create";
        }
        if (event_name == "update_user") {
            name = "user_action";
            value = "update";
        }
        if (event_name == "customer_feedback") {
            name = "customer_feedback";
            value = "--";
        }
        if (event_name == "ticket_note_added") {
            name = "note_action";
            value = "create";
        }
        return [{
            "name": name,
            "value": value
        }];
    },
    get_subscription_name: function (bundle) {
        var zap_name = "Freshdesk Zapier Zap";

        try {
            zap_name = bundle.zap.action.service.name + " -> " + bundle.zap.name;
        } catch (e) {
            zap_name = bundle.zap.name;
        }
        return zap_name;
    },
    pre_subscribe: function (bundle) {
        bundle.request.url = "https://" + bundle.auth_fields.domain_name + ".freshdesk.com/webhooks/subscription.json";
        //bundle.request.url="https://wildcards1.freshpo.com/webhooks/subscription.json";

        bundle.request.method = "POST";

        var request_data = {
            "url": bundle.target_url,
            "name": bundle.zap.link,
            "description": this.get_subscription_name(bundle),
            "event_data": this.get_event_data(bundle.event, bundle.trigger_fields)
            //,
            //"performer_data":{"type":"3"}
        };

        //var fields = this.get_fields_for_trigger(bundle.event, bundle.trigger_fields);
        //if( fields )
        //    request_data.fields = fields;
        bundle.request.data = JSON.stringify(request_data);
        return bundle.request;
    },
    post_subscribe: function (bundle) {
        var subscribe_data = z.JSON.parse(bundle.response.content);
        subscribe_data.link = bundle.link;
        return subscribe_data;
    },
    pre_unsubscribe: function (bundle) {
        bundle.request.url = "https://" + bundle.auth_fields.domain_name + ".freshdesk.com/webhooks/subscription/";
        //bundle.request.url="https://wildcards1.freshpo.com/webhooks/subscription/";
        bundle.request.url = bundle.request.url + bundle.subscribe_data.id + ".json";
        bundle.request.method = "DELETE";
        bundle.request.data = JSON.stringify({
            "name": bundle.zap.link
        });
        return bundle.request;
    },
    new_ticket_trigger_catch_hook: function (bundle) {
        return this.get_ticket_data(bundle);
    },
    new_user_trigger_catch_hook: function (bundle) {
        return this.get_user_data(bundle);
    },
    update_user_trigger_catch_hook: function (bundle) {
        return this.get_user_data(bundle);
    },
    ticket_updated_trigger_catch_hook: function (bundle) {
        return this.get_ticket_data(bundle);
    },
    ticket_note_added_trigger_catch_hook: function (bundle) {
        var note_data = this.get_ticket_data(bundle);
        var note_conversion_data = {
            "note_private": function (key, value) {
                key = "private",
                    value = value ? "Yes" : "No";
                return [key, value];
            }
        };
        note_data = this.beautify(note_data, "note_", note_conversion_data);
        return note_data;
    },
    get_fields_for_trigger: function (event_name, trigger_fields) {
        var fields = "ticket";
        if (event_name == "ticket_note_added") {
            fields = "notes";
        }
        if (event_name == "new_user") {
            fields = "user";
        }
        if (event_name == "update_user") {
            fields = "user";
        }
        return fields;
    },
    get_ticket_data: function (bundle) {
        var data = z.JSON.parse(bundle.request.content);
        return this.beautify(data.freshdesk_webhook, "ticket_");
    },
    get_user_data: function (bundle) {
        var data = z.JSON.parse(bundle.request.content);
        return this.beautify(data.freshdesk_webhook, "user_");
    },
    beautify: function (input, name_str, conversion_data) {
        var output = {};
        var replace_str = "";
        for (var attr in input) {
            var oattr = attr;
            var value = input[attr];
            if (attr.search(name_str) === 0 && attr.search("_id") === -1) {
                oattr = attr.replace(name_str, replace_str);
            }
            if (conversion_data && conversion_data[attr]) {
                var value_array = conversion_data[attr](attr, input[attr]);
                oattr = value_array[0];
                value = value_array[1];
            }
            output[oattr] = value;
        }
        return output;
    }
};