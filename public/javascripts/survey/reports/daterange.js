/*
    Module deals with events associated with date range.
*/
var SurveyDateRange = {
    isInitialized: false,
    month_names: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
    updateLink:function(dateRange){
        var timestamp = SurveyDateRange.convertDateToTimestamp(jQuery("#survey_date_range").val());
        var dateRange = SurveyDateRange.convertTimestampToDate(timestamp);
        jQuery("#survey_date_range_link").text(dateRange);
    },
    init:function(){
        if(!this.isInitialized){
                jQuery("#survey_date_range").val(dateRange);
                this.updateLink();
                this.isInitialized=true;
        }
        jQuery("#survey_date_range").attr("values",Date.today().toString("dddd, MMMM dd yyyy"));
        
        var dateFormat = getDateFormat('mediumDate').toUpperCase();
        var date = Helpkit.commonSavedReportUtil.getDateRangeDefinition(dateFormat);
        
        jQuery("#survey_date_range").daterangepicker({
            earliestDate: Date.parse('1/1/2009'),
            latestDate: new Date(),
            format: "DD MMM, YYYY",
            presetRanges: [
            {   text: I18n.t('helpdesk_reports.today'), 
                dateStart: 'Today', 
                dateEnd: 'Today',
                period : 'today'
            },
            {   text: I18n.t('helpdesk_reports.yesterday'), 
                dateStart: 'Today-1', 
                dateEnd: 'Today-1',
                period : 'yesterday' 
            },
            {   text: I18n.t('helpdesk_reports.this_week'), 
                dateStart: date.this_week_start, 
                dateEnd: 'Today' ,
                period : "this_week" 
            },
            {   text: I18n.t('helpdesk_reports.previous_week'), 
                dateStart: date.previous_week_start, 
                dateEnd: date.previous_week_end ,
                period : "previous_week" 
            },
            {   text: I18n.t('helpdesk_reports.last_num_days', { num : 7 }), 
                dateStart: 'Today-6', 
                dateEnd: 'Today' ,
                period : "last_7"
            },
            {
                text: I18n.t('helpdesk_reports.this_month'),
                dateStart: date.this_month_start,
                dateEnd: 'Today',
                period : "this_month"
            },
            {
                text: I18n.t('helpdesk_reports.previous_month'),
                dateStart: date.previous_month_start,
                dateEnd: date.previous_month_end,
                period : "previous_month"
            },
            {   text: I18n.t('helpdesk_reports.last_num_days', { num : 30 }),
                dateStart: 'Today-29', 
                dateEnd: 'Today',
                period : "last_30"
            },
            {
                text: I18n.t('helpdesk_reports.last_num_months',{ num : 3 } ),
                dateStart: date.last_3_months,
                dateEnd: 'Today',
                period : "last_3_months"
            },
            {   text: I18n.t('helpdesk_reports.last_num_days', { num : 90 }),
                dateStart: 'Today-89',  
                dateEnd: 'Today',
                period : "last_90"
            },
            {
                text: I18n.t('helpdesk_reports.last_num_months', { num : 6 }),
                dateStart: date.last_6_months,
                dateEnd: 'Today',
                period : "last_6_months"
            },
            {
                text: I18n.t('helpdesk_reports.this_year'),
                dateStart: date.this_year_start,
                dateEnd: 'Today',
                period : "this_year"
            }],
            presets: {
                dateRange: SurveyI18N.custom_daterange
            },
            dateFormat: getDateFormat('datepicker_escaped'),
            closeOnSelect: true,
            presetRangesCallback: true,
            onClose: function(){
                var timestamp = SurveyDateRange.convertDateToTimestamp(jQuery("#survey_date_range").val());
                var dateRange = SurveyDateRange.convertTimestampToDate(timestamp);
                jQuery("#survey_date_range_link").text(dateRange);
                SurveyState.filterChanged = true;
                SurveyState.fetch();
                SurveyDateRange.close();
            }
        }); 
        jQuery("#survey_date_range").bind('keypress keyup keydown', function(ev) {
        ev.preventDefault();
        return false;
        });
    },
    open:function(){
        jQuery("#survey_date_link_container").hide();
        jQuery("#survey_date_text_container").show();
        jQuery("#survey_date_range").trigger('click');
    },
    close:function(){
       jQuery("#survey_date_text_container").hide();
       jQuery("#survey_date_link_container").show();
    },
    convertDateToTimestamp:function(date){
        var dateArray = date.split("-");
        var d_from = new Date(dateArray[0]);
        var fromTimestamp = (("0" + (d_from.getDate())).slice(-2))  + "" + (("0" + (d_from.getMonth()+1)).slice(-2)) + "" +
                            (d_from.getYear()+1900);
        
        var timestamp = fromTimestamp;
        if(dateArray[1]){
            var d_to = new Date(dateArray[1]);
            var toTimestamp   = (("0" + (d_to.getDate())).slice(-2)) + "" + (("0" + (d_to.getMonth()+1)).slice(-2)) + "" +(d_to.getYear()+1900);
            timestamp += "-" + toTimestamp;
        }
        return timestamp;
    },
    convertTimestampToDate: function(timestamp){
        var formatDate = function(date){
            return date.substring(0,2)+ " " + SurveyI18N.month_names[(parseInt(date.substring(2,4)))]+", "+(date.substring(4,8));
        }
        var dateArray = timestamp.split("-");        
        fromDate  = formatDate(dateArray[0]);
        var dateRange = fromDate ;
        if(dateArray[1]){
            toDate    = formatDate(dateArray[1]);
            dateRange += "-" + toDate;
        }
        return dateRange;
    },
    convertDiffToTimestamp: function(date_diff){
        var date_range;
        var endDate = new Date();
        var startDate  = new Date(new Date().setDate(endDate.getDate()-date_diff));
        endDate = endDate.toLocaleDateString();
        startDate = startDate.toLocaleDateString();
        if(date_diff == 0){
            date_range = endDate;
        }
        else if(date_diff == 1){
            date_range = startDate;
        }
        else{
            date_range = startDate + "-" + endDate;
        }
        return  SurveyDateRange.convertDateToTimestamp(date_range);
    },
    convertTimestampToDateEn: function(timestamp){
        var formatDate = function(date){
            return date.substring(0,2)+ " " + SurveyDateRange.month_names[(parseInt(date.substring(2,4))-1)]+", "+(date.substring(4,8));
        }
         var dateArray = timestamp.split("-");        
        fromDate  = formatDate(dateArray[0]);
        var dateRange = fromDate ;
        if(dateArray[1]){
            toDate    = formatDate(dateArray[1]);
            dateRange += "-" + toDate;
        }
        return dateRange;
    }
}
