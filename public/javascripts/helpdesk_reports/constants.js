var HelpdeskReports = HelpdeskReports || {};

HelpdeskReports.Constants = {
    TicketVolume: {
        metrics: ["RECEIVED_RESOLVED_TICKETS"],
        report_type: "ticket_volume",
        params: {
            bucket                : false, 
            bucket_conditions     : [],
            group_by              : [],
            list                  : false, 
            list_conditions       : [],
            model                 : "TICKET",
            reference             : false,
            time_trend            : true, 
            time_trend_conditions : ["h", "doy", "dow", "w", "mon", "y", "qtr"], 
            time_spent            : false, 
            time_spent_conditions : []
        }
    }   
}
