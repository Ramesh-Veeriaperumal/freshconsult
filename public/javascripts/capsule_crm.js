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
        
        $('capsule-title').addClassName('paddingloading');
     
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
                $('capsule-title').removeClassName('paddingloading'); 
            }
        });
    },
    renderContact: function(contact) {
        // clear search result div
        $('cap-search-result').update("");
        $('cap-contact-summary').className = "user-details"; 
        var summary = '';
 
        if (contact.firstName || contact.lastName) {
            summary += '<div class="preview_pic"><img src="' + contact.pictureURL + '" /></div>'

            // build contact summary
            summary += '<a class="name" target="_blank" href="https://' + capsuleResource.options.domain.escapeHTML() + '/party/' + contact.id.escapeHTML() +'">';
            var name = '';
            if (contact.firstName) {
                name += contact.firstName.escapeHTML() + " "
            }
            if (contact.lastName) {
                name += contact.lastName.escapeHTML()
            }
            summary += name + '</a>';

            if (contact.jobTitle || contact.organisationName){
                summary += '<div class="jobtitle">'
                if (contact.jobTitle) {
                    summary += contact.jobTitle;
                }
                if (contact.organisationName) {
                    summary += ' at <a target="_blank" href="https://' + capsuleResource.options.domain.escapeHTML() + '/party/' + contact.organisationId.escapeHTML() +'">';
                    summary += contact.organisationName.escapeHTML();
                    summary += '</a>';
                }
                summary += '</div>';
            }

            if (!contact.contacts.email && !contact.contacts.phone && !contact.about) {
                summary += '<div class="info-data">no contact details have been recorded for ';
                summary += name.escapeHTML();
                summary += '</div>';
            }
            
        }

        if (contact.name) {
            summary += '<div class="preview_pic"><img src="' + contact.pictureURL + '" /></div>'

            summary += '<a class="name" target="_blank" href="https://' + capsuleResource.options.domain.escapeHTML() + '/party/' + contact.id.escapeHTML() +'">';
            summary += contact.name.escapeHTML();
            summary += '</a>';

            if (!contact.contacts.email && !contact.contacts.phone && !contact.about) {
                summary += '<div class="info-data">no contact details have been recorded for ';
                summary += contact.name.escapeHTML();
                summary += '</div>';
            } 
        }
        summary += '<span class="seperator"></span>';
        
        if (contact.contacts.email) {
            summary += '<h5>Email</h5><div class="minimum">';
            var emails = CapsuleWidget.toArray(contact.contacts.email);
            for (i=0; i < emails.length; i++) {
                if (i>0) {
                    summary += '<br/>';
                }
                summary += CapsuleWidget.showContactEmail(emails[i]);
            }
            summary += '</div>';
        }
        

        if (contact.contacts.phone) {
            summary += '<h5>Phone</h5><div class="minimum">';
            var phones = CapsuleWidget.toArray(contact.contacts.phone);
            for (i=0; i < phones.length; i++) {
                if (i>0) {
                    summary += '<br/>';
                }
                summary += CapsuleWidget.showContactPhone(phones[i]);
            }
            summary += '</div>';
        }

        if (contact.about) {
            summary += '<h5>About</h5><div class="minimum">';
            summary += contact.about.escapeHTML();
            summary += '</div>';
        }
        
        summary += '<span class="seperator"></span>';
        // add note to contact
        summary += '<h5>Add note to Capsule</h5>';
        summary += '<span id="cap-note-added" class="error"></span>';
        summary += '<form id="cap-note" onsubmit="CapsuleWidget.addNote(this,capsuleResource);return false;"><textarea id="capsule-note-text" name="note"></textarea><div><input type="submit" class="button" id="submit" value="Add a note"></div>';
        summary += '<input type="hidden" name="contactId" value="' + contact.id.escapeHTML() + '"/>';
        summary += '</form>';
         
        $('cap-contact-summary').update(summary);
        $('capsule-title').removeClassName('paddingloading'); 
    },
    showContactEmail: function(email) {
        var content = '<a href="mailto:' + email.emailAddress.escapeHTML() + '">' + email.emailAddress.escapeHTML() + '</a>';
        if (email.type) {content += '<span class="sub"> (' + email.type.escapeHTML() + ')</span>';}
        return content;
    },
    showContactPhone: function(phone) {
        var content = phone.phoneNumber.escapeHTML();
        if (phone.type) {content += '<span class="sub"> (' + phone.type.escapeHTML() + ')</span>';}
        return content;
    },
    searchContacts: function(theForm, resource) {
        if (theForm['q'].value == '') {
            alert('Please enter a name or email to search.');
            return;
        } 
        $('capsule-title').addClassName('paddingloading'); 
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
                CapsuleWidget.processSearch(response);
                // enable_submit($('cap-search'));
                $('capsule-title').removeClassName('paddingloading');  
            }
        });
    },
    
    processFailure: function(responseEvt){
       $('capsule-title').removeClassName('paddingloading');  
       errorResult = '<center class="info-error"><b>Error in retrieving Contact information!!!</b><br />'
       switch(responseEvt.status){
         case 401:
            errorResult += "Please verify your API Key";
         break;
         case 502:
            errorResult += "Slow internet connetion or Capsule is down";
         break;
      }
      errorResult += "</center>"
      $('cap-search-result').update(errorResult);
    },
    
    processSearch: function(response) {
		response = response.responseJSON;
        if (response.parties.person || response.parties.organisation) {
            var found = response.parties['@size'];

            // only a single contact found in search - show that.
            if (found == 1) {
                if (response.parties.person) {CapsuleWidget.renderContact(response.parties.person);}
                if (response.parties.organisation) {CapsuleWidget.renderContact(response.parties.organisation);}
                return;
            }

            var searchResults = '<div class="info-data">' + found + ' Matching contacts found in Capsule.<br /> Click the contact for more details</div><ul>';

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
            var notFoundText = '<div class="info-data">No matching contacts found.</div>';
                notFoundText += '<span class="seperator"></span>';
            if (typeof(capsuleBundle)!='undefined' && capsuleBundle.reqEmail && capsuleBundle.reqEmail != '') {
                notFoundText += '<div  class="highlight">Add this contact to Capsule CRM?</div>';
                notFoundText += '<form id="cap-person" onsubmit="CapsuleWidget.addContact(this,capsuleResource);return false;">';
                notFoundText += '<label for="name"><h5>Name</h5></label><input type="text" id="name" name="name" value="' + capsuleBundle.reqName.escapeHTML() + '">';
                notFoundText += '<label for="org"><h5>Company</h5></label><input type="text" id="org" name="org" value="' + capsuleBundle.reqOrg.escapeHTML() + '">';
                notFoundText += '<label for="phone"><h5>Phone Number</h5></label><input type="text" id="phone" name="phone" value="' + capsuleBundle.reqPhone.escapeHTML() + '">';
                notFoundText += '<label>Email</label>';
                notFoundText += '<input type="text" name="email" value="' + capsuleBundle.reqEmail.escapeHTML() + '" />';
                notFoundText += '<span class="seperator"></span>';
                notFoundText += '<input class="uiButton" type="submit" id="submit" value="Add contact">';
                notFoundText += '</form>'
            } else {
                notFoundText += '</p>';
            }

            $('cap-search-result').update(notFoundText);
        }
        $('capsule-title').removeClassName('paddingloading');
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
            alert('Name is required.');
            return;
        }
        $('capsule-title').addClassName('paddingloading'); 
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
        $('capsule-title').addClassName('paddingloading');
        if (theForm['note'].value == '') {
            alert('please enter a note.');
            return;
        }
        //disable_submit($('cap-note'));
        var more_info = "\n- via Freshdesk for - " + window.location;
        var note = theForm.note.value + more_info; // + '\nfor Freshdesk ticket #' + ticket_id;

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
                $('capsule-title').removeClassName('paddingloading');                
                $('cap-note-added').update('Note successfully added to Capsule CRM');
            }
        });
    }
}

capsuleResourceOptions = {
	anchor: "capsule_widget",
	domain: $('capsule_widget').getAttribute('domain').escapeHTML(),
	ssl_enabled: true,
	app_name:"Capsule CRM",
	content_type: "application/xml",
	enable_resource_cache: false,
	application_content: function() {
		var content = '<div class="negtive-margin"><h3 id="capsule-title" class="title paddingloading">';
		content += '<span class="searchicon" onclick="$(\'cap-search\').toggle()"></span>';
		content += $('capsule_widget').getAttribute('title').escapeHTML() + '</h3>';
	   content += '<div id="capsule-content" class="content">';
		content += '<form style="display:none;" id="cap-search" onsubmit="CapsuleWidget.searchContacts(this,capsuleResource); return false;">';
		content += '<input placeholder="Search Capsule" type="text" name="q" value=""/>';
		content += '</form>';
		content += '<div id="cap-search-result"></div>';
		content += '<div id="cap-contact-summary"></div>';
		content += '</div></div>'; // close capsule-content
		return content;
	},
	application_resources: [{
		resource: 'api/party?limit=10&stamp=' + new Date().valueOf() + '&qe=' + encodeURI(CapsuleWidget.searchTerm()),
		on_success: CapsuleWidget.processSearch,
		on_failure: CapsuleWidget.processFailure
	}]
};

   if (typeof(capsuleBundle) != 'undefined' && capsuleBundle.t) {
   	capsuleResourceOptions.username = capsuleBundle.t;
   	capsuleResourceOptions.password = "x";
   	capsuleResource = new Freshdesk.Widget(capsuleResourceOptions);
   } else {
   	capsuleResourceOptions.login_content = function() {
   		return '<form onsubmit="capsuleResource.login(this); return false;" class="form">' + '<label>Authentication Key</label><input type="password" id="username"/>' + '<input type="hidden" id="password" value="X"/>' + '<input type="submit" value="Login" id="submit">' + '</form>';
   	};
   	capsuleResource = new Freshdesk.Widget(capsuleResourceOptions);
   };
   
