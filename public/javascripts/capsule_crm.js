/*
<div id="capsule_widget" domain="hirickross.capsulecrm.com">
	<div id="content">Capsule widget</div>
</div>
<script type="text/javascript"> 
	CustomWidget.include_js('capsule_crm.js');
	capsuleBundle={
		t:"748b80fb0f4ecd19b68561dcc39c9f4f",
		reqId:"{{requester.id}}", 
		reqName:"{{requester.name}}",
		reqOrg:"{{requester.organization.name}}", 
		reqPhone:"{{requester.phone}}",
		reqEmail:"{{requester.email}}"};
</script> 

*/

CapsuleWidget = {
    toArray: function(objectOrArray) {
        if (!objectOrArray) {return new Array();}
        else if (objectOrArray instanceof Array) {return objectOrArray;}
        else {
            var newArray =	new Array();
            newArray[0] = objectOrArray;
            return newArray;
        }
    },
    showContact: function(id, resource) {
        var parameters = $H({
            username: resource.options.username,
            password: resource.options.password,
            domain: resource.options.domain,
            ssl_enabled: resource.options.ssl_enabled,
            method: 'get',
            enable_resource_cache: resource.options.enable_resource_cache,
            content_type: 'application/json',
            resource: 'api/party/' + escape(id)
        });

        new Ajax.Request('/http_request_proxy/fetch', {
            asynchronous: true,
            evalScripts: true,
            method: 'get',
            parameters: parameters,
            onSuccess: function (response) {
                if (response.responseJSON.person || response.responseJSON.organisation) {
                    var person = response.responseJSON.person;
                    var organisation = response.responseJSON.organisation;

                    if (person) {CapsuleWidget.renderContact(person);}
                    if (organisation) {CapsuleWidget.renderContact(organisation);}
                }
            }
        });
    },
    renderContact: function(contact) {
        // clear search result div
        $('cap-search-result').update("");
        var summary = '<br/>';

        summary += '<table>';
        if (contact.firstName || contact.lastName) {
            summary += '<tr><td style="width:60px;"><img src="' + contact.pictureURL + '"  width="50" height="50" /></td><td>'

            // build contact summary
            summary += '<h5 style="font-size:16px; margin: 0px;"><a target="_capsule" href="https://' + capsuleResource.options.domain.escapeHTML() + '/party/' + contact.id.escapeHTML() +'">';
            var name = '';
            if (contact.firstName) {
                name += contact.firstName.escapeHTML() + " "
            }
            if (contact.lastName) {
                name += contact.lastName.escapeHTML()
            }
            summary += name + '</a></h5>';

            if (contact.jobTitle || contact.organisationName){
                summary += '<p>'
                if (contact.jobTitle) {
                    summary += contact.jobTitle;
                }
                if (contact.organisationName) {
                    summary += ' at <a target="_capsule" href="https://' + capsuleResource.options.domain.escapeHTML() + '/party/' + contact.organisationId.escapeHTML() +'">';
                    summary += contact.organisationName.escapeHTML();
                    summary += '</a>';
                }
                summary += '</p>';
            }

            if (!contact.contacts.email && !contact.contacts.phone && !contact.about) {
                summary += '<p>no contact details have been recorded for ';
                summary += name.escapeHTML();
                summary += '</p>';
            }

            summary += "</td></tr>";
        }

        if (contact.name) {
            summary += '<tr><td><img src="' + contact.pictureURL + '"  width="50" height="50" /></td><td>'

            summary += '<h5 style="font-size:16px"><a target="_capsule" href="https://' + capsuleResource.options.domain.escapeHTML() + '/party/' + contact.id.escapeHTML() +'">';
            summary += contact.name.escapeHTML();
            summary += '</a></h5>';

            if (!contact.contacts.email && !contact.contacts.phone && !contact.about) {
                summary += '<p>no contact details have been recorded for ';
                summary += contact.name.escapeHTML();
                summary += '</p>';
            }

            summary += "</td></tr>";
        }
        summary += '</table>'

        if (contact.contacts.email) {
            summary += '<h5>Email</h5><p class="minimum">';
            var emails = CapsuleWidget.toArray(contact.contacts.email);
            for (i=0; i < emails.length; i++) {
                if (i>0) {
                    summary += '<br/>';
                }
                summary += CapsuleWidget.showContactEmail(emails[i]);
            }
            summary += '</p>';
        }

        if (contact.contacts.phone) {
            summary += '<h5>Phone</h5><p class="minimum">';
            var phones = CapsuleWidget.toArray(contact.contacts.phone);
            for (i=0; i < phones.length; i++) {
                if (i>0) {
                    summary += '<br/>';
                }
                summary += CapsuleWidget.showContactPhone(phones[i]);
            }
            summary += '</p>';
        }

        if (contact.about) {
            summary += '<h5>About</h5><p class="minimum">';
            summary += contact.about.escapeHTML();
            summary += '</p>';
        }

        // add note to contact
        summary += '<h5>Add note to Capsule</h5>'
        summary += '<form id="cap-note" onsubmit="CapsuleWidget.addNote(this,capsuleResource);return false;"><textarea style="width:180px;" name="note"></textarea><input type="submit" id="submit" value="Add a note">';
        summary += '<input type="hidden" name="contactId" value="' + contact.id.escapeHTML() + '"/><span id="cap-note-added"></span>';
        summary += '</form>'

        $('cap-contact-summary').update(summary);
    },
    showContactEmail: function(email) {
        var content = '<a href="mailto:' + email.emailAddress.escapeHTML() + '">' + email.emailAddress.escapeHTML() + '</a>';
        if (email.type) {content += '<span class="sub"> ' + email.type.escapeHTML() + '</span>';}
        return content;
    },
    showContactPhone: function(phone) {
        var content = phone.phoneNumber.escapeHTML();
        if (phone.type) {content += '<span class="sub"> ' + phone.type.escapeHTML() + '</span>';}
        return content;
    },
    searchContacts: function(theForm, resource) {
        if (theForm['q'].value == '') {
            alert('please enter a name to search.');
            return;
        }

        //disable_submit($('cap-search'));
        $('cap-contact-summary').update('');
        var parameters = $H({
            username: resource.options.username,
            password: resource.options.password,
            domain: resource.options.domain,
            ssl_enabled: resource.options.ssl_enabled,
            method: 'get',
            enable_resource_cache: resource.options.enable_resource_cache,
            content_type: 'application/json',
            resource: 'api/party?limit=10&stamp=' + new Date().valueOf() + '&qe=' + encodeURI(theForm.q.value)
        });

        new Ajax.Request('/http_request_proxy/fetch', {
            asynchronous: true,
            evalScripts: true,
            method: 'get',
            parameters: parameters,
            onSuccess: function (response) {
                CapsuleWidget.processSearch(response.responseJSON);
                // enable_submit($('cap-search'));
            }
        });
    },
    processSearch: function(response) {
        if (response.parties.person || response.parties.organisation) {
            var found = response.parties['@size'];

            // only a single contact found in search - show that.
            if (found == 1) {
                if (response.parties.person) {CapsuleWidget.renderContact(response.parties.person);}
                if (response.parties.organisation) {CapsuleWidget.renderContact(response.parties.organisation);}
                return;
            }

            var searchResults = '<p>' + found + ' matching contacts found in Capsule. Click the contact for more details</p><ul>';

            if (response.parties.person) {
                var people = CapsuleWidget.toArray(response.parties.person);
                for (var i = 0; i < people.length; i++) {
                    var person = people[i];
                    searchResults += '<li><a href="#" onclick="CapsuleWidget.showContact(' + person.id.escapeHTML() +', capsuleResource);return false;">' + (person.firstName?person.firstName.escapeHTML():'') + ' ' + (person.lastName?person.lastName.escapeHTML():'') + '</a></li>'
                }
            }

            if (response.parties.organisation) {
                var organisations = CapsuleWidget.toArray(response.parties.organisation);
                for (var i = 0; i < organisations.length; i++) {
                    var organisation = organisations[i];
                    searchResults += '<li><a href="#" onclick="CapsuleWidget.showContact(' + organisation.id.escapeHTML() +', capsuleResource);return false;">' + organisation.name.escapeHTML() + '</a></li>'
                }
            }

            searchResults += "</ul>";
            $('cap-search-result').update(searchResults);
        } else {
            var notFoundText = '<p>No matching contacts found.';

            if (typeof(capsuleBundle)!='undefined' && capsuleBundle.reqEmail && capsuleBundle.reqEmail != '') {
                notFoundText += 'To add this contact to Capsule use the form below.</p>';
                notFoundText += '<form id="cap-person" onsubmit="CapsuleWidget.addContact(this,capsuleResource);return false;">';
                notFoundText += '<label for="name"><h5>Name</h5></label><input type="text" id="name" name="name" value="' + capsuleBundle.reqName.escapeHTML() + '">';
                notFoundText += '<label for="org"><h5>Company</h5></label><input type="text" id="org" name="org" value="' + capsuleBundle.reqOrg.escapeHTML() + '">';
                notFoundText += '<label for="phone"><h5>Phone Number</h5></label><input type="text" id="phone" name="phone" value="' + capsuleBundle.reqPhone.escapeHTML() + '">';
                notFoundText += '<h5>Email</h5>' + capsuleBundle.reqEmail.escapeHTML();
                notFoundText += '<input type="hidden" name="email" value="' + capsuleBundle.reqEmail.escapeHTML() + '"/><br/>';
                notFoundText += '<input type="submit" id="submit" value="Add contact">';
                notFoundText += '</form>'
            } else {
                notFoundText += '</p>';
            }

            $('cap-search-result').update(notFoundText);
        }
    },

    searchTerm: function() {
        var name = "";
        if (typeof(capsuleBundle)!='undefined') {return capsuleBundle.reqEmail;}
        if ($("freshdesk_ticket_requester")) {name = $("freshdesk_ticket_requester").innerHTML;}
        if ($("sidebar").select('.email a')[0] &&  $("sidebar").select('.email a')[0].firstChild.data) {
            name = $("sidebar").select('.email a')[0].getAttribute('href').substring(7);
        }
        return name;
    },

    addContact: function(theForm, resource) {
        if (theForm['name'].value == '') {
            alert('name is required.');
            return;
        }

        //disable_submit($('cap-person'));
        var parameters = $H({
            username: resource.options.username,
            password: resource.options.password,
            domain: resource.options.domain,
            ssl_enabled: resource.options.ssl_enabled,
            method: 'post',
            enable_resource_cache: resource.options.enable_resource_cache,
            content_type: 'application/xml',
            resource: 'api/person',
            entity_name: 'person'
        });

        if (theForm['name'].value.indexOf(" ") > 0) {
            parameters.set('person[firstName]',theForm['name'].value.substring(0, theForm['name'].value.indexOf(" ")));
            parameters.set('person[lastName]',theForm['name'].value.substring(theForm['name'].value.indexOf(" ") + 1));
        } else {
            parameters.set('person[firstName]',theForm['name'].value);
        }

        if (theForm['org'].value != '') {parameters.set('person[organisationName]', theForm['org'].value);}
        if (theForm['email'].value != '') {parameters.set('person[contacts][email][emailAddress]', theForm['email'].value);}
        if (theForm['phone'].value != '') {parameters.set('person[contacts][phone][phoneNumber]', theForm['phone'].value);}

        new Ajax.Request('/http_request_proxy/fetch', {
            asynchronous: true,
            evalScripts: true,
            method: 'post',
            parameters: parameters,
            onSuccess: function (response) {
                window.location.reload();
            }
        });
    },
    addNote: function(theForm,resource) {
        $('cap-note-added').update('');
        if (theForm['note'].value == '') {
            alert('please enter a note.');
            return;
        }
        //disable_submit($('cap-note'));
        var note = theForm.note.value; // + '\nfor Freshdesk ticket #' + ticket_id;

        // clear the note out
        theForm.note.value = '';

        var parameters = $H({
            username: resource.options.username,
            password: resource.options.password,
            domain: resource.options.domain,
            ssl_enabled: resource.options.ssl_enabled,
            method: 'post',
            enable_resource_cache: resource.options.enable_resource_cache,
            content_type: 'application/xml',
            resource: 'api/party/' + escape(theForm.contactId.value) + '/history',
            entity_name: 'historyItem',
            'historyItem[note]': note
        });

        new Ajax.Request('/http_request_proxy/fetch', {
            asynchronous: true,
            evalScripts: true,
            method: 'post',
            parameters: parameters,
            onSuccess: function (response) {
                // enable_submit($('cap-note'));
                $('cap-note-added').update(' note added');
            }
        });
    }
}

if (typeof(capsuleBundle)!='undefined' && capsuleBundle.t) {
    capsuleResource = new Freshdesk.Widget({
        anchor: "capsule_widget",
        domain: $('capsule_widget').getAttribute('domain').escapeHTML(),
        ssl_enabled: true,
        content_type: "application/xml",
        enable_resource_cache: false,
        application_content: function() {
            var content = "<div id='capsule-content'>";
            content += '<form id="cap-search" onsubmit="CapsuleWidget.searchContacts(this,capsuleResource); return false;">';
            content += '<input type="text" name="q" value="' + CapsuleWidget.searchTerm() + '"/>';
            content += '<input type="submit" id="submit" value="Search Capsule"/>'
            content += '</form>';
            content += '<div id="cap-search-result"></div>';
            content += '<div id="cap-contact-summary"></div>';
            content += "</div>"; // close capsule-content
            return content;
        },
        username: capsuleBundle.t,
        password: "x",
        application_resources: [ {
                resource: 'api/party?limit=10&stamp=' + new Date().valueOf() + '&qe=' + encodeURI(CapsuleWidget.searchTerm()),
                on_success: CapsuleWidget.processSearch
            } ]
    });
} else {
    capsuleResource = new Freshdesk.Widget({
        anchor: "capsule_widget",
        domain: $('capsule_widget').getAttribute('domain').escapeHTML(),
        ssl_enabled: true,
        content_type: "application/xml",
        enable_resource_cache: false,
        application_content: function() {
            var content = "<div id='capsule-content'>";
            content += '<form id="cap-search" onsubmit="CapsuleWidget.searchContacts(this,capsuleResource); return false;">';
            content += '<input type="text" name="q" value="' + CapsuleWidget.searchTerm() + '"/>';
            content += '<input type="submit" id="submit" value="Search Capsule"/>'
            content += '</form>';
            content += '<div id="cap-search-result"></div>';
            content += '<div id="cap-contact-summary"></div>';
            content += "</div>"; // close capsule-content
            return content;
        },
        login_content: function () {
            return  '<form onsubmit="capsuleResource.login(this); return false;" class="form">' +
                '<label>Authentication Key</label><input type="password" id="username"/>' +
                '<input type="hidden" id="password" value="X"/>' +
                '<input type="submit" value="Login" id="submit">' +
                '</form>';
        },
        application_resources: [ {
                resource: 'api/party?limit=10&stamp=' + new Date().valueOf() + '&qe=' + encodeURI(CapsuleWidget.searchTerm()),
                on_success: CapsuleWidget.processSearch
            } ]
    });
};
