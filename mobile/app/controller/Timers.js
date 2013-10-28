window.already_loaded = false;
Ext.define('Freshdesk.controller.Timers', {
    extend: 'Ext.app.Controller',
    slideLeftTransition: { type: 'slide', direction: 'left' },
    slideRightTransition: { type: 'slide', direction: 'right'},
    config:{
        routes:{
            'tickets/timer/:id': 'timer',
            'tickets/addTimer/:id' : 'addTimer',
            'tickets/editTimer/:id' : 'editTimer'
        },
        refs:{
            timerContainer:"timerContainer",
            timer:"timer",
            ticketTimer:"ticketTimer",
            timerForm:"timerForm",
        }
    },
    timer : function(id,callBack){
        var detailsContainer = this.getTimerContainer();
        detailsContainer.ticket_id = id;
        anim = Freshdesk.anim || { type: 'slide', direction: 'left' };
            var url = '/helpdesk/tickets/'+id+'/time_sheets';
            Ext.getStore("Timers").getProxy()._url=url;
            Ext.getStore("Timers").load();
                detailsContainer.items.items[1].show();
                Ext.Viewport.animateActiveItem(detailsContainer, anim);
    },

    addTimer : function(id){
        this.initTimerForm(id);
        var timer_container = this.getTicketTimer();
        timer_container.ticket_id = id;
        timer_container.items.items[0].items.items[2].items.items[1].show();
        timer_container.items.items[0].items.items[2].items.items[0].hide();
    },

    initTimerForm : function(id){
        var timeForm = this.getTicketTimer();
        var formObj = timeForm.items.items[1];
        // formObj.reset();
        formObj.items.items[0].items.items[1].reset();
        formObj.items.items[0].items.items[2].reset();
        formObj.items.items[0].items.items[3].reset();
        formObj.items.items[0].items.items[4].reset();
        formObj.show();
        timeForm.items.items[0].setTitle('Add Timer');
        formObj.items.items[0].items.items[5].hide();
        formObj.setUrl('/helpdesk/tickets/'+id+'/time_sheets');
        formObj.setMethod('POST');
        if(!Freshdesk.time_sheet_agents_list){
                opts = {
                url: '/mobile/tickets/ticket_properties/'+id,
                };
            FD.Util.getJSON(opts,this.populateAgent,this);
        }
        formObj.show();
        timeForm.show();
    },

    populateAgent : function(res){
        var timeForm = this.getTicketTimer();
        var formObj = timeForm.items.items[1];
        formObj.addCls('timer_form');
        var response = JSON.parse(res.responseText);
        var select_object = new Array();
        for(var i=0;i<response.length;i++)
            {
                var ticket_field = response[i].ticket_field;
                if(ticket_field.field_name == "responder_id")
                {   
                    choices=ticket_field.choices;
                    for(key in choices){
                    opt = choices[key];
                    formObj.items.items[0].items.items[0]._options.push({text:opt[0],value:opt[1]});
                    select_object.push({text:opt[0],value:opt[1]});
                    }
                }
            }
            formObj.items.items[0].items.items[0].updateOptions(select_object);
        timeForm.show();
        Freshdesk.time_sheet_agents_list = true;
    },

    populateEditTimerForm : function(id,res){
        if(!Freshdesk.time_sheet_agents_list){
            opts = {
                url: '/mobile/tickets/ticket_properties/'+id,
            };
            FD.Util.getJSON(opts,this.populateAgent,this);
        }
        var timeForm = this.getTicketTimer();
        var formObj = timeForm.items.items[1];
        var response = JSON.parse(res.responseText);
        response = response.item;
        var time_entry = response.time_entry;
        timeForm.items.items[0].setTitle('Edit Timer');
        formObj.setUrl('/helpdesk/time_sheets/'+id);
        formObj.setMethod('PUT');
        var date_obj = new Date(time_entry.executed_at);
        // var minutes_spent = (((time_entry.timespent)%1)*0.6);
        // var mins = parseFloat(minutes_spent.toFixed(2));
        // var mins_displayed = parseInt(mins*100);
        // if(mins_displayed<10)
        // mins_displayed = "0"+mins_displayed;
        // var hours_spent = parseInt(time_entry.timespent);
        formObj.items.items[0].items.items[1].setValue(time_entry.timespent);
        formObj.items.items[0].items.items[0].setValue(time_entry.user_id);
        
        formObj.items.items[0].items.items[5].ticket_id = time_entry.ticket_id;
        formObj.items.items[0].items.items[5].timer_id = id;
        formObj.items.items[0].items.items[5].show();
        
        if(time_entry.billable){
            formObj.items.items[0].items.items[2].setChecked(true);
        }
        else
        {   
            formObj.items.items[0].items.items[2].setChecked(false);   
        }
        formObj.items.items[0].items.items[3].setValue(date_obj);
        formObj.items.items[0].items.items[4].setValue(time_entry.note);
        timeForm.ticket_id = time_entry.ticket_id;
        timeForm.items.items[0].items.items[2].items.items[0].show();
        timeForm.items.items[0].items.items[2].items.items[1].hide();
        formObj.show();
        timeForm.show();
    },

    editTimer : function(id){
        var detailsContainer = this.getTimerContainer();
        var timer_container = this.getTicketTimer();
        timer_container.ticket_id = detailsContainer.ticket_id ;

        var ajaxOpts = {
            url: '/helpdesk/time_sheets/'+id,
            params:{
                format:'json',
                '_method':'get',
                'action':'show'
            },
            scope:this
        },
        ajaxCallb = function(res){
            this.populateEditTimerForm(id,res);
        };
        FD.Util.ajax(ajaxOpts,ajaxCallb,this,false);
    },


    launch: function () {
        this.callParent();
    },
    initialize: function () {
        this.callParent();;
    }
});
