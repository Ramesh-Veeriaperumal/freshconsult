Ext.define('Freshdesk.view.TimerForm', {
    extend: 'Ext.form.Panel',
    alias: 'widget.timerForm',
    cls:'timer_form',
    requires: ['Ext.field.Email','Ext.field.Hidden','Ext.field.Toggle','Ext.field.DatePicker','Ext.field.Text'],
    config: {
        layout:'vbox',
        align:'stretch',
        method:'POST',
        url:'/helpdesk/time_sheets/',
        items : [
            {
                xtype: 'fieldset',
                defaults:{
                        labelWidth:'20%'
                },
                items :[
                    {
                        xtype: 'selectfield',
                        label: 'Agents',
                        name:'time_entry[user_id]',
                        options: [
                        {text: 'Select Agent',  value: '1'},
                        {text: 'Second Option', value: '2'},
                        {text: 'Third Option',  value: '3'}
                        ]
                    },
                    {
                        xtype: 'textfield',
                        label: 'Hours',
                        placeHolder:'HH:MM',                       
                        name: 'time_entry[hhmm]'
                    },
                    {
                        xtype: 'checkboxfield',
                        name: 'time_entry[billable]',
                        label: 'Billable',
                        value: '1'
                    },
                                        {
                        xtype: 'datepickerfield',
                        label: 'On',
                        name: 'time_entry[executed_at]',
                        dateFormat : 'F j, Y',
                        value: new Date()
                    },
                    {
                        xtype: 'textareafield',
                        name: 'time_entry[note]',
                        placeHolder:'Add Note..',
                        height:200,
                        required:true,
                        clearIcon:false
                    },{
                        xtype:'button',
                        text:'Delete Time Entry',
                        cls:'delete_timer_button',
                        ui:'lightBtn',
                        handler:function(){ 

                            Ext.Msg.confirm('Delete','Do you want to delete the time entry?',
                            function(btnId){
                                if(btnId == 'no' || btnId == 'cancel'){
                                    //do nothing..
                                }
                                else{
                                    this.getParent().getParent().getParent().hide();
                                    location.href = "#tickets/timer/"+this.ticket_id;
                                    FD.Util.deleteTimer(this.timer_id,this.ticket_id); 
                                }
                            },
                            this
                        );

                            
                        }, 

                    },                   
                ]
            }
        ]
    }
});