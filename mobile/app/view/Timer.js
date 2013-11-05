Ext.define("Freshdesk.view.Timer", {
    extend: "Ext.dataview.List",
    alias: "widget.timer",
    config: {
        cls:'timerList',
        loadingText: false,
        emptyText: '<div class="empty-list-text">There are no time entries available for this ticket</div>',
        onItemDisclosure: false,
        itemTpl: Ext.create('Ext.XTemplate',
                ['<tpl for=".">',
                      '<div class="time-spent-container">',
                        '{time_entry.timespent:this.formatTime}',  
                      '</div>',
                      '<div> ', 
                        '<span class="agent-name">{time_entry.agent_name}</span>',
                        '<span class="arrow icon-arrow-right">&nbsp',
                        '</span>',
                        '<tpl if="time_entry.billable">',
                            '<span class = "billable">',
                              '&nbsp;',
                            '</span>',
                        '</tpl>',  
                        '<div class="muted date">on {time_entry.executed_at:this.formatedTimerDate}</div>', 
                      '</div>',
                  '</tpl>',
            ].join(''),
                {
                        time_in_words : function(item){
                            return FD.Util.humaneDate(item);
                        },
                        formatTime : function(timespent){
                            var minutes_spent = (((timespent)%1)*0.6);
                            var mins = parseFloat(minutes_spent.toFixed(2));
                            var mins_displayed = parseInt(mins*100);
                            if(mins_displayed<10)
                            mins_displayed = "0"+mins_displayed;
                            var hours_spent = parseInt(timespent);
                            return hours_spent+":"+mins_displayed;
                        },
                        formatedDate : function(item){
                            return FD.Util.formatedDate(item);
                        },
                        formatedTimerDate : function(date_item){
                            var monthNames = [ "Jan", "Feb", "Mar", "Apr", "May", "June","July", "Aug", "Sep", "Oct", "Nov", "Dec" ];
                            var dayNames = ["Sun", "Mon", "Tue", "Wed", "Thur", "Fri", "Sat"];
                            var date_obj = new Date(date_item);
                            var current_date_obj = new Date();
                            var year_to_be_displayed;
                            if (date_obj.getFullYear() == current_date_obj.getFullYear())
                              year_to_be_displayed = '';
                            else
                              year_to_be_displayed = ', '+date_obj.getFullYear();
                            var current_day = date_obj.getDay();
                            return   dayNames[current_day] + ', ' +monthNames[date_obj.getMonth()] + ' ' + date_obj.getDate() + year_to_be_displayed + '' ;
                        },
                })
    }
});