Ext.define('Freshdesk.controller.Tickets', {
    extend: 'Ext.app.Controller',
    slideLeft: { type: 'slide', direction: 'left' },
    slideRight: { type: 'slide', direction: 'right'},
    coverUp:{type: 'cover', direction: 'up'},
    config:{
        before: {
            addNote : 'showIfNot',
            reply   : 'showIfNot',
            resolve   : 'showIfNot',
            'delete'   : 'showIfNot',
            scenarios   : 'showIfNot',
            close   : 'showIfNot'
        },
        routes:{
            'tickets/show/:id': 'show',
            'tickets/reply/:id': 'reply',
            'tickets/addNote/:id': 'addNote',
            'tickets/resolve/:id': 'resolve',
            'tickets/delete/:id': 'delete',
            'tickets/scenarios/:id': 'scenarios',
            'tickets/close/:id': 'close'
        },
    	refs:{
            ticketDetailsContainer:"ticketDetailsContainer",
            ticketsListContainer:"ticketsListContainer",
            ticketReply:"ticketReply",
            ticketNote : 'ticketNote',
            newTicketContainer : 'newTicketContainer'
    	}
    },
    show: function(id,callBack){
        var detailsContainer = this.getTicketDetailsContainer();
        anim = Freshdesk.anim || { type: 'slide', direction: 'left' };
        if(Freshdesk.cancelBtn){
            Ext.Viewport.animateActiveItem(detailsContainer, anim);
        }
        else{
            Ext.Ajax.request({
                url: '/helpdesk/tickets/'+id,
                headers: {
                    "Accept": "application/json"
                },
                success: function(response) {
                    var resJSON = JSON.parse(response.responseText).helpdesk_ticket,
                    convContainer = this.getConversationContainer();
                    resJSON.notes = resJSON.notes || resJSON.public_notes ;
                    //saving in local variable ..
                    this.ticket = resJSON;
                    convContainer.setData(resJSON);
                    detailsContainer.showCoversations(true);
                    detailsContainer.items.items[0].setTitle('Ticket: '+id);
                    detailsContainer.ticket_id=id,
                    Ext.Viewport.animateActiveItem(detailsContainer, anim);
                    callBack ? callBack() : '' ;
                    delete Freshdesk.anim;
                },
                failure: function(response){
                    Ext.Msg.alert('Some thing went wrong!', "We are sorry . Some thing went wrong! Our technical team is looking into it.");
                },
                scope: this
            });
        }
        Freshdesk.cancelBtn=false;
        Freshdesk.anim = undefined;
    },
    reply : function(id){
        this.initReplyForm(id);
        var replyForm = this.getTicketReply();
        replyForm.ticket_id = id;
        Ext.ComponentQuery.query('#cannedResponsesPopup')[0].formContainerId="ticketReplyForm";
        Ext.Viewport.animateActiveItem(replyForm, this.coverUp);
    },
    addNote : function(id){
        this.initNoteForm(id);
        var noteForm = this.getTicketNote();
        noteForm.ticket_id = id;
        Ext.ComponentQuery.query('#cannedResponsesPopup')[0].formContainerId="ticketNoteForm";
        Ext.Viewport.animateActiveItem(noteForm, this.coverUp);
    },
    scenarios : function(id){
        FD.Util.check_user();
        var scenarios = Ext.ComponentQuery.query('#scenarioies')[0];
        //setting the data to canned response popup list
        scenarios.items.items[0].setData(FD.current_account.scn_automations);
        scenarios.ticket_id = id;
        Ext.Viewport.animateActiveItem(scenarios, this.coverUp);
    },
    close: function(id){
        Ext.Msg.confirm('Close ticket : '+id,'Do you want to Close this ticket?',
            function(btnId){
                if(btnId == 'no' || btnId == 'cancel'){
                    Freshdesk.cancelBtn=true;
                    location.href="#tickets/show/"+id;
                }
                else{
                    Ext.Ajax.request({
                        url: '/support/tickets/close_ticket/'+id,
                        method:'GET',
                        headers: {
                            "Accept": "application/json"
                        },
                        callback: function(req,success,response){
                            if(success){
                                location.href="#tickets/show/"+id;
                            }
                            else{
                                location.href="#tickets/show/"+id;
                                Ext.Msg.alert('Some thing went wrong!', "We are sorry . Some thing went wrong! Our technical team is looking into it.");   
                            }
                        }
                    });
                }
            }
        );
    },
    resolve : function(id){
        Ext.Msg.confirm('Mark as Resolve ticket : '+id,'Do you want to mark this ticket as Resolve?',
            function(btnId){
                if(btnId == 'no' || btnId == 'cancel'){
                    Freshdesk.cancelBtn=true;
                    location.href="#tickets/show/"+id;
                }
                else{
                    Ext.Ajax.request({
                        url: '/helpdesk/tickets/update/'+id,
                        method:'POST',
                        params:{
                            'helpdesk_ticket[status]' : 4
                        },
                        headers: {
                            "Accept": "application/json"
                        },
                        callback: function(req,success,response){
                            if(success){
                                location.href="#tickets/show/"+id;
                            }
                            else{
                                location.href="#tickets/show/"+id;
                                Ext.Msg.alert('Some thing went wrong!', "We are sorry . Some thing went wrong! Our technical team is looking into it.");   
                            }
                        }
                    });
                }
            }
        );
    },
    'delete' : function(id){
        Ext.Msg.confirm('Move to trash ticket : '+id,'Do you want to move this ticket to Trash?',
            function(btnId){
                if(btnId == 'no' || btnId == 'cancel'){
                    Freshdesk.cancelBtn=true;
                    location.href="#tickets/show/"+id;
                }
                else{
                    Ext.Ajax.request({
                        url: '/helpdesk/tickets/'+id,
                        params:{
                            '_method':'delete',
                            'action':'destroy'
                        },
                        headers: {
                            "Accept": "application/json"
                        },
                        callback: function(req,success,response){
                            if(success){
                                location.href="#tickets/show/"+id;
                            }
                            else{
                                location.href="#tickets/show/"+id;
                                Ext.Msg.alert('Some thing went wrong!', "We are sorry . Some thing went wrong! Our technical team is looking into it.");   
                            }
                        }
                    });
                }
            }
        );
    },
    initNoteForm : function(id){
        FD.Util.check_user();
        var notForm = this.getTicketNote(),
        formObj = notForm.items.items[1];
        notForm.items.items[0].setTitle('Ticket : '+id);
        formObj.reset();
        formObj.setUrl('/helpdesk/tickets/'+id+'/notes');
        if(FD.current_user.is_customer)
            formObj.setUrl('/support/tickets/'+id+'/notes');    
    },
    initReplyForm : function(id){
        var replyForm = this.getTicketReply(),reply_emails = [],
        formObj = replyForm.items.items[1],
        fieldSetObj = formObj.items.items[0];
        replyForm.ticket_id = id;
        replyForm.items.items[0].setTitle('Ticket : '+id);

        formObj.reset();
        if(!FD.current_account){
            location.href="#tickets/show/"+id;
            return;
        }
        //setting from mails if the reply_emails are more else hide the from..
        FD.current_account.reply_emails.forEach(function(value,key){
            reply_emails.push({text:value,value:value});
        })
        fieldSetObj.items.items[0].setOptions(reply_emails).show();
        if(reply_emails.length === 1) 
            fieldSetObj.items.items[0].setHidden(true);

        //setting to email
        fieldSetObj.items.items[1].setValue(this.ticket.requester.email).show();
        //setting canned response and solution href
        fieldSetObj.items.items[8].setData({id:id});

        //setting the url 
        formObj.setUrl('/helpdesk/tickets/'+id+'/notes');
    },
    getConversationContainer : function(){
        return this.getTicketDetailsContainer().items.items[1].items.items[1].items.items[0];
    },
    _redirectToConversation : function(id){
        location.href="#tickets/show/"+id;
    },
    _conversationLoaded : function(){
        return !!this.getConversationContainer().getData();
    },
    showIfNot : function(action){
        FD.Util.check_user();
        if(!this._conversationLoaded()) {
            var args = action._args;
            args.push(function(){
                action.resume();
            });
            this.show.apply(this,args);
        }
        else{
            action.resume();
        }
    }

});
