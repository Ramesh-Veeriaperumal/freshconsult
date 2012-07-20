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
            newTicketContainer : 'newTicketContainer',
            ticketTweetForm   : 'ticketTweetForm',
            ticketFacebookForm : 'ticketFacebookForm'
    	}
    },
    renderDetails: function(ticketDetails,callBack){
        var resJSON = JSON.parse(ticketDetails.responseText).helpdesk_ticket,
        convContainer = this.getConversationContainer(),
        detailsContainer = this.getTicketDetailsContainer(),
        id = resJSON.display_id;
        resJSON.notes = resJSON.notes || resJSON.public_notes ;
        //removing meta source notes..
        resJSON.notes = Ext.Array.filter(resJSON.notes,function(t){return t.source_name !== 'meta'})
        //saving in local variable ..
        this.ticket = resJSON;
        convContainer.setData(resJSON);
        detailsContainer.showCoversations(true);
        detailsContainer.items.items[0].setTitle('Ticket: '+id);
        detailsContainer.ticket_id=id;
        detailsContainer.requester_id=resJSON.requester.id;
        //Ext.Viewport.animateActiveItem(detailsContainer, anim);
        detailsContainer.items.items[1].items.items[1].addActionListeners(detailsContainer);
        callBack ? callBack() : '' ;
        if(Freshdesk.notification) {
            var msgContainer = Ext.get("notification_msg");
            msgContainer.setHtml('<b>'+Freshdesk.notification.success+'</b>');
            msgContainer.toggleCls('hide');
            Ext.defer(function(){
                Ext.get("notification_msg").toggleCls('hide')
            },3500);
        }
        Freshdesk.notification=undefined;
        delete Freshdesk.anim;
    },
    show: function(id,callBack){
        var detailsContainer = this.getTicketDetailsContainer();
        anim = Freshdesk.anim || { type: 'slide', direction: 'left' };
        detailsContainer.items.items[0].setTitle('Ticket: '+id);
        if(Freshdesk.cancelBtn){
            Ext.Viewport.animateActiveItem(detailsContainer, anim);
        }
        else{
            this.getConversationContainer().setData({loading:true});
            Ext.Viewport.animateActiveItem(detailsContainer, anim);
            var ajaxOpts = {
                url: '/helpdesk/tickets/show/'+id,
                params:{
                    format:'mobile'
                },
                scope:this
            },
            ajaxCallb = function(res){
                this.renderDetails(res,callBack)
            };
            FD.Util.ajax(ajaxOpts,ajaxCallb,this,false);
        }
        Freshdesk.cancelBtn=false;
        Freshdesk.anim = undefined;
    },
    reply : function(id){
        //console.log(this.ticket.from_email, this.ticket.is_facebook, this.ticket.is_twitter)
        if(this.ticket.from_email){
            this.initReplyForm(id);
            var replyForm = this.getTicketReply();
            replyForm.ticket_id = id;
            Ext.ComponentQuery.query('#cannedResponsesPopup')[0].formContainerId="ticketReplyForm";
            Ext.Viewport.animateActiveItem(replyForm, this.coverUp);
        }

        if(this.ticket.is_twitter){
            var tweetForm = this.getTicketTweetForm();
            this.initTweetForm(id);
            tweetForm.ticket_id = id;
            Ext.Viewport.animateActiveItem(tweetForm, this.coverUp);
        }

        if(this.ticket.is_facebook){
            var facebookForm = this.getTicketFacebookForm();
            this.initFacebookForm(id);
            facebookForm.ticket_id = id;
            Ext.Viewport.animateActiveItem(facebookForm, this.coverUp);   
        }
        
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

        var self = this,
            messageBox = new Ext.MessageBox({
            title:'Close ticket',
            message: 'Do you want to update ticket status to "Close"?',
            modal:true,
            buttons: [
                {
                    text:'No',
                    handler:function(){
                        Freshdesk.cancelBtn=true;
                        location.href="#tickets/show/"+id;
                        messageBox.hide();
                    },
                    scope:self
                },
                {
                    text:'Yes',
                    handler:function(){
                        messageBox.hide();
                        var opts = { url: '/support/tickets/close_ticket/'+id },
                        callBack = function(){
                            Freshdesk.notification={
                                success : "The ticket has been closed."
                            };
                            location.href="#tickets/show/"+id;
                        };
                        FD.Util.ajax(opts,callBack,this);
                    },
                    scope:self
                }
            ]
        }).show();
    },
    resolve : function(id){

        var self = this,
            messageBox = new Ext.MessageBox({
            title:'Resolve ticket',
            message: 'Do you want to update ticket status to "Resolve"?',
            modal:true,
            buttons: [
                {
                    text:'No',
                    handler:function(){
                        Freshdesk.cancelBtn=true;
                        location.href="#tickets/show/"+id;
                        messageBox.hide();
                    },
                    scope:self
                },
                {
                    text:'Yes',
                    handler:function(){
                        messageBox.hide();
                        var opts = {
                            url: '/helpdesk/tickets/update/'+id,
                            method:'POST',
                            params:{
                                'helpdesk_ticket[status]' : 4
                            },
                            headers: {
                                "Accept": "application/json"
                            }
                        },
                        callBack = function(){
                            Freshdesk.notification={
                                success : "The ticket has been resolved."
                            };
                            location.href="#tickets/show/"+id;
                        };
                        FD.Util.ajax(opts,callBack,this);
                    },
                    scope:self
                }
            ]
        }).show();
    },
    'delete' : function(id){

        var self = this,
            messageBox = new Ext.MessageBox({
            title: 'Delete Ticket',
            message: 'Do you want to delete this ticket (#'+id+')?',
            modal:true,
            buttons: [
                {
                    text:'No',
                    handler:function(){
                        Freshdesk.cancelBtn=true;
                        location.href="#tickets/show/"+id;
                        messageBox.hide();
                    },
                    scope:self
                },
                {
                    text:'Yes',
                    handler:function(){
                        messageBox.hide();
                        var opts = {
                           url: '/helpdesk/tickets/'+id,
                            params:{
                                '_method':'delete',
                                'action':'destroy'
                            },
                            headers: {
                                "Accept": "application/json"
                            } 
                        },
                        callBack = function(){
                            Freshdesk.notification={
                                success : "The ticket has been deleted."
                            };
                            location.href="#tickets/show/"+id;
                        };
                        FD.Util.ajax(opts,callBack,this);
                    },
                    scope:self
                }
            ]
        }).show();
    },
    initNoteForm : function(id){
        FD.Util.check_user();
        var notForm = this.getTicketNote(),
        formObj = notForm.items.items[1],
        autoTechStore = Ext.getStore('AutoTechnician');
        notForm.items.items[0].setTitle('Ticket : '+id);
        formObj.reset();
        formObj.setUrl('/helpdesk/tickets/'+id+'/notes');
        if(FD.current_user.is_customer){
            formObj.setUrl('/support/tickets/'+id+'/notes');  
        }
        if(FD.current_user.is_agent && !autoTechStore.isLoaded()){
            autoTechStore.load();
        }
        formObj.items.items[0].items.items[4].setValue('');
    },
    initReplyForm : function(id){
        var replyForm = this.getTicketReply(),reply_emails = [],
        formObj = replyForm.items.items[1],
        fieldSetObj = formObj.items.items[0],
        cc_emails,bcc_emails;
        replyForm.ticket_id = id;
        replyForm.items.items[0].setTitle('Ticket : '+id);


        
        fieldSetObj.items.items[6].setLabel('Cc/Bcc :');
        fieldSetObj.items.items[6].reset();
        fieldSetObj.items.items[7].setHidden(true).reset();
        fieldSetObj.items.items[8].reset();
        if(!FD.current_account){
            location.href="#tickets/show/"+id;
            return;
        }

        //setting from mails if the reply_emails are more else hide the from..
        FD.current_account.reply_emails.forEach(function(value,key){
            reply_emails.push({text:value,value:value});
        })
        fieldSetObj.items.items[0].setOptions(reply_emails).show();
        fieldSetObj.items.items[0].setValue(this.ticket.selected_reply_email);
        if(reply_emails.length === 1) 
            fieldSetObj.items.items[0].setHidden(true);

        //setting to email
        fieldSetObj.items.items[1].setValue(this.ticket.requester.email).show();
        //setting canned response and solution href
        fieldSetObj.items.items[8].setData({id:id});


        ticket_details = this.getConversationContainer().getData();
        if(ticket_details.notes.length > 0) {
            cc_emails = ticket_details.cc_email ? ticket_details.cc_email.cc_emails : [];
        }
        else {
            cc_emails = ticket_details.to_cc_emails; 
        } 
        cc_emails = cc_emails && cc_emails.join(',')

        if(cc_emails){
            fieldSetObj.items.items[6].setLabel('Cc :');
            fieldSetObj.items.items[7].setHidden(false);
        }
        fieldSetObj.items.items[6].setValue(cc_emails)

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
    },
    initTweetForm : function(id){
        var tweetForm = this.getTicketTweetForm(),tweet_handles = [],
        formObj = tweetForm.items.items[1],
        fieldSetObj = formObj.items.items[0];
        tweetForm.ticket_id = id;
        tweetForm.items.items[0].setTitle('Ticket : '+id);

        if(!FD.current_account){
            location.href="#tickets/show/"+id;
            return;
        }

        //setting from mails if the reply_emails are more else hide the from..
        FD.current_account.twitter_handles.forEach(function(value,key){
            tweet_handles.push({text:value.screen_name,value:value.id});
        })
        fieldSetObj.items.items[0].setOptions(tweet_handles).show();
        fieldSetObj.items.items[0].setValue(this.ticket.fetch_twitter_handle);
        if(tweet_handles.length === 1) 
            fieldSetObj.items.items[0].setHidden(true);

        //setting to tweet
        fieldSetObj.items.items[1].setValue(this.ticket.requester.twitter_id).show();
        
        if(this.ticket.requester.twitter_id)
            fieldSetObj.items.items[5].setValue('@'+this.ticket.requester.twitter_id).show();

        //setting the url 
        formObj.setUrl('/helpdesk/tickets/'+id+'/notes');
    },
    initFacebookForm : function(id){
        var facebookForm = this.getTicketFacebookForm(),
        formObj = facebookForm.items.items[1],
        fieldSetObj = formObj.items.items[0];
        facebookForm.ticket_id = id;
        facebookForm.items.items[0].setTitle('Ticket : '+id);

        if(!FD.current_account){
            location.href="#tickets/show/"+id;
            return;
        }

        
        if(this.ticket.fb_post && this.ticket.fb_post.facebook_page) {
            fieldSetObj.items.items[0].setValue(this.ticket.fb_post.facebook_page.page_name);
        }

        //setting to facebook
        fieldSetObj.items.items[1].setValue(this.ticket.requester.name).show();
        
        if(this.ticket.is_fb_message) {
            fieldSetObj.items.items[5].setPlaceHolder('Reply *');
        }
        else {
            fieldSetObj.items.items[5].setPlaceHolder('Comment *');   
        }
            
        fieldSetObj.items.items[5].setValue('');
        //setting the url 
        formObj.setUrl('/helpdesk/tickets/'+id+'/notes');
    }

});
