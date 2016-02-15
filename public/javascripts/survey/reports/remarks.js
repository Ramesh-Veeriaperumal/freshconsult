/*
    Module deals with activities related to remarks contents.
*/
var SurveyRemark = {
        currentPage:1,
        totalPages:1,
        pageLimit:10,
        fetch:function(){
            SurveyUtil.showOverlay();
            var self = this;
            this.currentPage=1;
            jQuery.ajax({
                type: 'GET',
                url: self.makeURL(),
                success:function(data){
                    if(SurveyState.RemarksOnly){
                        self.remarksConditionalRender(data);
                        SurveyUtil.hideOverlay();
                        SurveyState.RemarksOnly = false;
                    }
                    else{
                        jQuery.ajax({
                        type: 'GET',
                        url: SurveyUtil.makeURL("aggregate_report"),
                        success:function(aggregate_data){
                            SurveyUtil.updateData(aggregate_data);
                            SurveyUtil.mapResults();
                            self.remarksConditionalRender(data);
                            SurveyUtil.hideOverlay();
                        },
                        error: function (error) {
                            console.log(error);
                        }
                        });
                    }
                },
                error: function (error) {
                 console.log(error);
                }
             });
        },
        remarksConditionalRender:function(data){   
            var self = this;
            var type = SurveyReportData.type.remarks;
            var id = jQuery('.report-panel-left').find('ul li.active').data('id');
            SurveySummary.reset(type,id);
            self.renderContent(data);
            jQuery("#survey_report_main_content").unblock();
            SurveyReport.showLayout();
            self.pageLimit = data.page_limit;
            self.totalPages = Math.ceil(data.total/self.pageLimit);
            jQuery('#survey_responses').pageless({
                 url: self.makeURL(),
                 totalPages: self.totalPages,
                 currentPage: (self.currentPage++),
                 loaderImage:"/images/animated/loading.gif",
                 loaderMsg: SurveyI18N.loading_remarks,
                 params:{page:self.currentPage},
                 scrape: SurveyRemark.renderPageless
            });

        },
        makeURL:function(){
            return SurveyUtil.makeURL("responses");
        },
        renderContent:function(data,isPageless){
            if(!SurveyReport.isEmptyChart()){
                SurveyReport.showReport();
                var remarks = SurveyRemark.format(data.remarks);    
                if((remarks.length==0 && !isPageless) || (jQuery('.survey-response-row').length == 0 && isPageless)){
                    jQuery('div.empty-chart').text(SurveyI18N.no_remarks);
                }
                var remarkHTML = JST["survey/reports/template/content_response_layout"]({remarks:remarks});
                if(isPageless){ return remarkHTML; }
                jQuery("#survey_responses").html(remarkHTML); 
                jQuery("#survey_report_filter_by_component").show();
                this.show();
            }  
            SurveyTab.renderSidebar();
        },
        show:function(){
            SurveyState.toggle(SurveyState.RESPONSE.type);
        },
        renderPageless:function(data){
            var html = SurveyRemark.renderContent(JSON.parse(data),true);
            return html;
        },
        renderFilterBy:function(){
            jQuery('#survey_report_filter_by_component').html(JST["survey/reports/template/filter_by_component"]());
            SurveyState.setFilter('rating_list',data.rating);
        },
        format:function(data){
            var remarks = [];
            for(var i=0;i<data.length;i++){
                data[i].customer.createdAt = data[i].created_at;
                if(data[i].survey_remark){
                    remarks.push({
                            msg:data[i].survey_remark.feedback.body,
                            rating:data[i].rating,
                            customer:data[i].customer,
                            agent: data[i].agent,
                            group: data[i].group,
                            ticket: data[i].surveyable
                    });
                }
            }
            return remarks;
        }
}