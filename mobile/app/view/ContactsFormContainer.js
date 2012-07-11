Ext.define('Freshdesk.view.ContactsFormContainer', {
    extend: 'Ext.Container',
    requires:['Ext.TitleBar'],
    alias: 'widget.contactsFormContainer',
    initialize: function () {

        this.callParent(arguments);
        var me = this;
        var backButton = {
            text:'Cancel',
            xtype:'button',
            handler:this.backToListView,
            align:'left',
            ui:'headerBtn',
            scope:this
        };

        var submitButton = {
            xtype:'button',
            align:'right',
            text:'Save',
            ui:'headerBtn',
            handler:function(){
                var submitOptions = {
                    success:function(form,response){
                        me.onSaveSuccess(response);
                    },
                    failure:function(form,response){
                        var errorHtml='Please correct the bellow errors.<br/>';
                        for(var index in response.errors){
                            var error = response.errors[index],eNo= +index+1;
                            errorHtml = errorHtml+'<br/> '+eNo+'.'+error[0]+' '+error[1]
                        }
                        Ext.Msg.alert('Errors', errorHtml, Ext.emptyFn);
                    },
                    url:'/contacts'
                };

                if(me.user_id){
                   submitOptions.url='/contacts/'+me.user_id;
                   submitOptions.params={
                        _method:'put'
                    }
                }
                me.items.items[1].submit(submitOptions);
                
            }
        }

        var topToolbar = {
            xtype: "titlebar",
            docked: "top",
            title:'Info',
            ui:'header',
            items: [
                backButton,
                submitButton
            ]
        };
        var contactForm = {
            xtype:'contactform'
        };
        this.add([topToolbar,contactForm]);
    },
    onSaveSuccess : function(data){
        location.href="#contacts/show/"+data.record.user.id;
    },
    backToListView: function(){
        console.log(this.user_id)
        this.user_id ? Freshdesk.backBtn = true : Freshdesk.cancelBtn = true;
        Freshdesk.cancelBtn=true;
        location.href="#dashboard/contacts";
    },
    setUserId: function(user_id){
        this.user_id=user_id;
    },
    getUserId: function(){
        return this.user_id;
    },
    config: {
        layout:'fit'
    }
});
