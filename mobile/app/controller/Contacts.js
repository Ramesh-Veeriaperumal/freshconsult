Ext.define('Freshdesk.controller.Contacts', {
    extend: 'Ext.app.Controller',
    slideRight: { type: 'slide', direction: 'right'},
    slideLeft: { type: 'slide', direction: 'left'},
    coverUp:{type:'cover',direction:'up'},
    config:{
        routes:{
            'contacts/show/:id' : 'show',
            'contacts/new'  : 'create'
        },
    	refs:{
            contactsListContainer:"contactsListContainer",
            contactDetails:"contactDetails",
            contactsFormContainer:'contactsFormContainer'
    	}
    },
    show: function(id){
        var contactDetails = this.getContactDetails();

        Ext.Ajax.request({
            url: '/contacts/'+id,
            headers: {
                "Accept": "application/json"
            },
            success: function(response) {
                var resJson = JSON.parse(response.responseText),
                user = resJson.user;
                contactDetails.items.items[1].setData(user);
                Ext.Viewport.animateActiveItem(contactDetails, { type: 'slide', direction: 'left'});
            },
            failure: function(response){
                
            }
        });
    },
    create: function(){
        var contactsFormContainer = this.getContactsFormContainer(),
        userProfilePanel = contactsFormContainer.items.items[1].items.items[0],
        userForm=contactsFormContainer.items.items[1];
        userForm.reset();
        userProfilePanel.setData({});
        userProfilePanel.hide();
        Ext.Viewport.animateActiveItem(contactsFormContainer, this.coverUp);
        contactsFormContainer.setUserId(undefined);
    }
});
