HelpdeskReports.Reports_home = (function($){

    const constants = {
        base_url    : "/reports",
        qna : {
            ans_url : '/v2/qna/fetch_qna_metric',
            recent_questions_url : '/v2/qna/fetch_recent_questions',
        },
        timeout : 30000,
        insights : {
            page_size : 6,
            config_url: "/v2/insights/fetch_insights_config",
            save_config_url: "/v2/insights/save_insights_config",
            insights_url : '/v2/insights/fetch_insights_metric',
        },
        min_agent_limit : 6
    }

    var _FD = {
        current_page : 1,
        total_pages : 0,
        visibility: {},
        fetchInsightConfig: function() {
            var self = this; 
            var config = {
                url: constants.base_url + constants.insights.config_url,
                success: function(res) {

                    self.insightsConfig = self.populateConfigData(res);

                    //Cache the config
                    if (typeof (Storage) !== "undefined") {
                      // window.localStorage.setItem("insights_config", Browser.stringify(res));
                      window.localStorage.setItem("insights_config", JSON.stringify(res));
                    }
                    self.fetchInsights(self.insightsConfig);
                },
                error: function(res) {
                    //Unable to fetch insights config
                }
            }
            self.makeAjaxRequest(config);
        },
        populateConfigData: function (res) {

            var self = this;
            var locals = HelpdeskReports.locals;
            var widget_ids = _.keys(res.config);

            $.each(widget_ids,function(idx,key) {
                var widget_config = res.config[key];

                if(widget_config.groups == undefined || widget_config.groups.length == 0) {
                    widget_config.groups = [];
                    widget_config.groups_label = [];
                    if( widget_config.widget_type == "2") {
                      // widget_config.groups.push(locals.groups[0][0].toString());
                      widget_config.groups.push(locals.groups[0][0]);
                      widget_config.groups_label.push(locals.groups[0][1]);
                      
                    } else if (widget_config.widget_type == "3") {
                      // widget_config.groups.push(locals.groups[0][0].toString());
                      // widget_config.groups.push(locals.groups[1][0].toString());
                      widget_config.groups.push(locals.groups[0][0]);
                      widget_config.groups.push(locals.groups[1][0]);

                      //Labels
                      widget_config.groups_label.push(locals.groups[0][1]);
                      widget_config.groups_label.push(locals.groups[1][1]);
                    }
                }
                if(widget_config.products == undefined) {
                    widget_config.products = [];
                    widget_config.products_label = [];
                }
                res.config[key] = widget_config;
            });

            return res;
        },
        fetchInsights : function(insightsConfig) {
            var self = this;
            var locals = HelpdeskReports.locals.groups;

            self.showLoader('.insights-content');

            var widget_ids = _.keys(insightsConfig.config);
            //construct req
            var req = {
                metric_type : "ticket",
                insights : []
            };

            $.each(widget_ids,function(idx,key) {
                var widget_config = insightsConfig.config[key];
                var widget_req = {
                    "metric" : widget_config.metric,
                    "widget_id" : key,
                    "widget_type" : widget_config.widget_type,
                    "filter" : []
                };

                //Add group filter
                if(widget_config.groups.length > 0) {
                    widget_req.filter.push({
                        "key" : "group_id",
                        "value" : widget_config.groups.join(",")
                    });
                }

                //Add products filter
                if(widget_config.products.length > 0) {
                     widget_req.filter.push({
                        "key" : "product_id",
                        "value" : widget_config.products.join(",")
                    });
                }

                req.insights.push(widget_req);
            });

            var self = this;
            var config = {
                type : 'post',
                url : constants.base_url + constants.insights.insights_url,
                contentType : 'application/json',
                data : Browser.stringify(req),
                success : function(res){
                    if(res.hasOwnProperty('error')) {
                      self.populateError('insights',res.error);
                    } else {
                      self.populateInsights(res);
                    }
                },
                error : function(res){
                }
            }
            self.makeAjaxRequest(config)
        },
        fetchAnswer : function(question) {
            var self = this;
            //Hide recent questions
            $('.recent-questions').addClass('hide');
            self.showLoader('.search-results');
            $("#search-query").addClass('loading');
            
            var self = this;
            var config = {
                type : 'post',
                data : { question : question },
                url : constants.base_url + constants.qna.ans_url,
                success : function(res) {
                    $("#search-query").removeClass('loading');
                    if(res.hasOwnProperty('error')) {
                      self.hideLoader('.search-results');
                      $(".answer-section").show();
                      self.populateError('qna', res.error);
                    }else{
                      self.populateAnswer(question, res);
                    }
                    self.fetchRecentQuestions();
                },
                error : function(res) {
                  $("#search-query").removeClass('loading');
                }
            }
            self.makeAjaxRequest(config)
        },
        fetchRecentQuestions : function() {
            var self = this;
            var config = {
                type : 'post',
                url : constants.base_url + constants.qna.recent_questions_url,
                success : function(res){
                    if(res.recent_questions.length == 0 ) {
                        $(".recent-questions .title").hide();
                    } else {
                        $(".recent-questions .title").show();
                        self.populateRecentQuestions(res)
                    }
                },
                error : function(res){
                }
            }
            self.makeAjaxRequest(config)
        },
        populateAnswer : function(question, res) {

            var self = this;

            self.hideLoader('.search-results');

            $answer_section  = $(".answer-section");
            $view_report_link = $(".view-report");

            $answer_section.show();
            $view_report_link.show();

            //Show specific report link as well
            $view_report_link.find("a").addClass('hide');

            if(question.question_type == "1" || question.question_type == "2") {
                if(res.chart_data != null) {
                  self.drawGraph(res);
                } else {
                  $(".graph-preview").hide();
                }
                $view_report_link.find("a[data-targets=other]").removeClass('hide')
            } else {
                $(".graph-preview").hide();
                $view_report_link.find("a[data-targets="+ question.question_type +"]").removeClass('hide')
            }

            var template_data = {
                agent : true,
                title : I18n.t('helpdesk_reports.qna.' + res.metric.toLowerCase()),
                val2 : res.variance != undefined ? (res.variance.value || 0) : (res.val2 || 0),
                variance : res.variance,
                q_type: question.question_type
            }
            
            //Apply transforms
            if( question.question_type == 3 || question.question_type == 4 || question.question_type == 5) {
              
              //Which agent question response has val1 as object
              if(question.question_type == 4) {
                if(res.val1 != null) {
                  template_data.val1 = res.val1.name;
                  template_data.pic_markup = res.val1.url;
                  template_data.show_pic = true;
                } else {
                  template_data.val1 = 'N.A';
                  template_data.show_pic = false;
                  template_data.show_empty_screen = true;
                }
              } else {
                if(res.val1 != null) {
                  template_data.val1 = res.val1 ;
                  template_data.show_empty_screen = false;
                } else {
                  template_data.show_empty_screen = true;
                }
              }

              if(res.metric_type == "Count") {
                template_data.val2 = template_data.val2;
              } else if(res.metric_type == "Avg") {
                template_data.val2 = HelpdeskReports.CoreUtil.timeMetricConversion(template_data.val2);
              } else if(res.metric_type == "Percentage") {
                template_data.val2 = template_data.val2 + "%";
              }
            } else if( question.question_type == 1 || question.question_type == 2 ) {
              if(res.val1 == null) {
                template_data.show_empty_screen = true;
              }
              template_data.val1 = res.val1 || 0;
              if(res.metric_type == "Count") {
                  template_data.val1 = template_data.val1;
              } else if(res.metric_type == "Avg") {
                  template_data.val1 = HelpdeskReports.CoreUtil.timeMetricConversion(template_data.val1);
              } else if(res.metric_type == "Percentage") {
                  template_data.val1 = template_data.val1 + "%";
              }
              template_data.val2 = template_data.val2 + "%";
            }
          
            var tmpl = JST["helpdesk_reports/templates/answer_widget_tmpl"]({ ans : template_data});
            $("[rel=answer-preview]").html(tmpl);
        },
        drawGraph : function(res) {
            var data = [];
            var self = this;
            var plot_type,unit_suffix;
            
            if(res.metric_type == "Percentage" ) {
              plot_type = "Percentage";
              unit_suffix = '%';
            } else if(res.metric_type == "Avg") {
              plot_type = _.max(res.chart_data.values) > 3600 ? "Hours" : "Mins";
              unit_suffix = plot_type;
            } else {
              plot_type = "Tickets";
              unit_suffix= '';
            }
            
            $(".graph-preview").show();
            if(res.metric_type == "Avg") {
              data.push({
                  name: I18n.t('helpdesk_reports.qna.' + res.metric.toLowerCase()),
                  data: res.chart_data.values.map(function(n){
                    return plot_type == "Hours" ? n/3600 : n/60;
                  }),
                  unit_suffix: unit_suffix
              });
            } else {
              data.push({
                  name: I18n.t('helpdesk_reports.qna.' + res.metric.toLowerCase()),
                  data: res.chart_data.values,
                  unit_suffix: unit_suffix
              });
            }
            
            var labels = [];
            $.each(res.chart_data.categories,function(i,el){
                 labels.push(moment(el).format("D MMM"));
            });

            var settings = {
                renderTo: 'graph-view',
                xAxisLabel: labels,
                chartData: data,
                xAxisType: 'number',
                legendDisable : false,
                yAxis_label : plot_type,
                qnaChart: true 
            }
            var day_trend = new lineChart(settings);
            day_trend.lineChartGraph();
        },
        populateRecentQuestions : function(res) {

            HelpdeskReports.locals.recent_questions = res.recent_questions;
            var tmpl = JST["helpdesk_reports/templates/recent_question_tmpl"]({
                data : res.recent_questions
            });
            $("[rel=raq]").html(tmpl);
        },
        populateInsights : function(resp) {

            var self = this;
            var config = self.insightsConfig.config;
            var all_groups = HelpdeskReports.locals.groups;
            var all_products = HelpdeskReports.locals.products;
            var widgetIds = _.keys(config);
            var current_outlier_count = 0;
            var is_first_load = $.isEmptyObject(self.visibility) ? true : false;
            
            if(resp['last_dump_time'] != null) {
                $('.last_updated').html(I18n.t("helpdesk_reports.insights.last_update",{ time : moment.unix(resp['last_dump_time']).fromNow()}));
            }
            
            $.each(widgetIds, function( id, key ) {
              resp[key] = $.extend({},resp[key],config[key]);
              resp[key].groups_value = [];
              resp[key].products_value = [];
              if(config[key].widget_type ==  2) {
                  resp[key].visibility = (resp[key].val1 != null && resp[key].val1 >= constants.min_agent_limit) ? 1 : 0;
              } else {
                  resp[key].visibility = (resp[key].variance.value != null && resp[key].variance.value >= parseInt(config[key].threshold)) ? 1 : 0;
              }
              if(is_first_load) {
                self.visibility[key] = resp[key].visibility;
                resp[key].highlight = false;
              } else {
                if(self.visibility[key] != resp[key].visibility) {
                  resp[key].highlight = true;
                } else {
                  resp[key].highlight = false;
                }
                //update the hash
                self.visibility[key] = resp[key].visibility;
              }
              //for pagination
              if(resp[key].visibility == 1) current_outlier_count++;
            });

            this.total_pages = Math.ceil( current_outlier_count / constants.insights.page_size );

            var tmpl = JST["helpdesk_reports/templates/insight_widget_tmpl"]({
                data : resp,
                page_size : constants.insights.page_size,
                is_customize_screen : false,
                is_edit_view : false,
                current_outlier_count: current_outlier_count
               });

            $("[rel=insights-content]").html(tmpl);

            //disable paginate buttons
            if(this.current_page == this.total_pages) {
                $(".pagination").find('.previous').addClass('disabled');
                $(".pagination").find('.next_page').addClass('disabled');
            }

            //Hide paginate and populate empty holder 
            if(this.total_pages == 0){
                $(".pagination").addClass('hide');
                $("[rel=insights-content]").html(JST["helpdesk_reports/templates/insight_empty_tmpl"]());
            }

            //Customize insights
            var tmpl = JST["helpdesk_reports/templates/insight_widget_tmpl"]({
                data : resp,
                page_size : constants.insights.page_size,
                is_edit_view : true,
                is_customize_screen : true,
                all_groups : HelpdeskReports.locals.groups,
                all_products : HelpdeskReports.locals.products,
                current_outlier_count: current_outlier_count
            });

            $("[rel=customize-insights-content]").html(tmpl);
            
            $(".filter_item").select2();
            $(".filter_compare").select2();

            //populate existing values
            $.each(widgetIds, function( id, key ) {
                //get the widget type
                var type = config[key].widget_type;
                if(type == '1') {
                    $(".edit-row[data-index=" + id + "] .js-insightGroups").select2('val',config[key].groups);
                    $(".edit-row[data-index=" + id + "] .js-insightProducts").select2('val',config[key].products);
                } else if( type == '2') {
                    $(".edit-row[data-index=" + id + "] .js-insightGroups").select2('val',config[key].groups);
                } else {
                    $(".edit-row[data-index=" + id + "] .js-insightGroup1").select2('val',config[key].groups[0]);
                    $(".edit-row[data-index=" + id + "] .js-insightGroup2").select2('val',config[key].groups[1]);
                }
            });
        },
        populateError: function(feature,error) {
          if(feature == 'qna') {
            $("[rel=answer-preview]").html(JST["helpdesk_reports/templates/qna_error_tmpl"]({error:error}));
          } else if( feature == 'insights') {
            $(".insights-content").html(JST["helpdesk_reports/templates/insight_error_tmpl"]({error:error}));
          }
        },
        saveInsights : function() {

          var self = this;
          var index = self.editingWidgetId;
          var parentIndex = self.editingIndex;
          var widgetType = self.current_edit.widget_type;
          var req = {
              config: {}
          };
          
          if(widgetType == 1 || widgetType == 3) {
            //Treshold validation
            var $target_row = $(".edit-row[data-index=" + parentIndex + "]");
            var threshold =  $target_row.find(".js-insightThreshold").attr("value");
            if(threshold == undefined || threshold == '') {
              $target_row.find(".missing_field").removeClass('hide');
              $target_row.find(".invalid_field").addClass('hide');
              return;
            } else {
              $target_row.find(".missing_field").addClass('hide');
              if(!(parseInt(threshold) >= 0 && parseInt(threshold) < 100)) {
                $target_row.find(".invalid_field").removeClass('hide');
                return;
              }else {
                $target_row.find(".invalid_field").addClass('hide');
              }
            }
          }
          req.config[index] = {
            metric: self.current_edit.metric,
            metric_type: self.current_edit.metric_type,
            widget_type: self.current_edit.widget_type,
            threshold: threshold,
            groups: [],
            products: []
          };

          if ( widgetType == "1" || widgetType == "2" ) {
            //When no option is selected pass empty array instead of -1
            var group_select = $(".edit-row[data-index=" + parentIndex + "] .js-insightGroups");
            var val = group_select.select2('val');
            req.config[index].groups = [];
            req.config[index].groups_label = [];
            if( val != null && val != -1) {
              req.config[index].groups.push(val);
              req.config[index].groups_label = group_select.find('option:selected').map(function () {
                                                     return this.text;
                                                 }).get();
            }
            if(widgetType == "1") {
                var product_select = $(".edit-row[data-index=" + parentIndex + "] .js-insightProducts");                                      
                var product_val = product_select.select2('val');
                req.config[index].products = [];
                req.config[index].products_label = [];
                if( product_val != null && product_val != -1) {
                  req.config[index].products.push(product_val);
                  req.config[index].products_label = product_select.find('option:selected').map(function () {
                                                      return this.text;
                                                  }).get();
                }
            }
          } else if ( widgetType == "3" ) {
              var first_group_select = $(".edit-row[data-index=" + parentIndex + "] .js-insightGroup1");
              req.config[index].groups = new Array(first_group_select.select2('val'));
              req.config[index].groups_label = first_group_select.find('option:selected').map(function () {
                                                        return this.text;
                                                    }).get();

              var second_group_select = $(".edit-row[data-index=" + parentIndex + "] .js-insightGroup2");
              req.config[index].groups = req.config[index].groups.concat(second_group_select.select2('val'));
              req.config[index].groups_label = req.config[index].groups_label.concat(second_group_select.find('option:selected').map(function () {
                                                        return this.text;
                                                    }).get());
          }

          jQuery("[rel=customize-insights-content]").html('<div class="sloading loading-small loading-block"></div>');
          
          //Destroy dialog, as save-on-close on dialog attr was destroying select2 before values were obtained.
          $("[role=dialog],.modal-backdrop").remove();
          $("body").removeClass('modal-open');
          
          var config = {
              type : 'post',
              url : constants.base_url + constants.insights.save_config_url,
              contentType : 'application/json',
              data : Browser.stringify(req),
              success : function(res){
                  jQuery("[rel=customize-insights-content]").html('');
                  $(".edit-row").remove();
                  self.insightsConfig = self.populateConfigData(res);
                  self.fetchInsights(self.insightsConfig);
              },
              error : function(res){
              }
          }
          self.makeAjaxRequest(config)
        },
        paginateInsights : function(target_page) {
            var $li = $(".widget-row");
            //$li.velocity('fadeOut');
            $li.hide();
            var start = (target_page - 1) * constants.insights.page_size;
            $sub = $li.slice(start,start + constants.insights.page_size);
            //$sub.velocity('fadeIn');
            $sub.show();

            //update pagination controls
            if(target_page == this.total_pages) {
                $(".pagination").find('.previous').removeClass('disabled');
                $(".pagination").find('.next_page').addClass('disabled');
            }
            if(target_page == 1) {
                $(".pagination").find('.previous').addClass('disabled');
                $(".pagination").find('.next_page').removeClass('disabled');
            }
        },
        makeAjaxRequest: function (args) {
            args.url = args.url;
            args.type = args.type ? args.type : "POST";
            args.dataType = args.dataType ? args.dataType : "json";
            args.data = args.data;
            args.success = args.success ? args.success : function () {};
            args.error = args.error ? args.error : function () {};
            var _request = $.ajax(args);
        },
        showLoader : function(container) {
            if($(container).find('.sloading').length == 0 ) {
              $(container).append('<div class="sloading loading-small loading-block"></div>');
            }
        },
        hideLoader : function(container) {
            $(container + ' .sloading').remove();
        },
        appendNoData : function(container) {
            var mkup = "<div class='no_data_to_display text-center muted mt20'><i class='ficon-no-data fsize-72'></i><div class='mt10'>No Data to Display </div></div>";
            if($('.' + container + ' .widget-content').length == 0) {
                $('.' + container + ' .widget-inner').html(mkup);
            } else {
                $('.' + container + ' .widget-content').html(mkup);
            }
        },
        bindEvents : function() {
            var _this = this;
            var $doc = $(document),
                $results = $(".search-results"),
                $pagination = $('.pagination'),
                $base = $(".base-content"),
                $left_section = $(".left-section"),
                $insights = $(".insights"),
                $popover = $(".question-popover"),
                $recent_questions = $('.recent-questions'),
                $selcted_queries = $(".selected-queries"),
                $input = $("#search-query"),
                $answer_section  = $(".answer-section");

            //Question complete
            $doc.on('question-complete.qna',function(ev,data){
                _this.last_question = data;
                _this.fetchAnswer(data);
            })

            $doc.on('question-focus.qna',function(ev,data){
                $input.val('');
                $results.velocity('fadeIn');
                $base.hide();
                $insights.hide();
                $answer_section.hide();
                $recent_questions.removeClass('hide');
                $left_section.addClass('active');
            });

            $doc.on('question-close.qna',function(ev,data){
                $results.velocity('fadeOut');
                $base.show();
                $insights.show();
                $left_section.removeClass('active');
            });

            $doc.on('question-cleared.qna',function(ev,data){
                $answer_section.hide();
                $recent_questions.removeClass('hide'); 
            });

            //pagination
            $pagination.on('click','[data-action="next"]',function() {
                if(!($(this).parent().hasClass('disabled'))){
                    _this.current_page += 1;
                    _this.paginateInsights(_this.current_page);
                }
            });
            $pagination.on('click','[data-action="prev"]',function() {
                if(!($(this).parent().hasClass('disabled'))){
                    _this.current_page -= 1
                    _this.paginateInsights(_this.current_page);
                }
            });

            $doc.on('click','[data-action="show-customize"]',function(){
                //$("[data-action='edit-widget']").velocity('fadeIn');
                $("[data-action='edit-widget']").show();
                $(".insights").addClass('hide-section');
                $(".configure-insight-widget").removeClass('hide');
                $(".insights-headline").removeClass('hide');
            });

            $doc.on('click','[data-action="close-customize"]',function(){
                //$("[data-action='edit-widget']").velocity('fadeOut');
                $(".insights").removeClass('hide-section');
                $(".insights-headline").addClass('hide');
                $("[data-action='edit-widget']").hide();
                $(".configure-insight-widget").addClass('hide');
                $(".edit-row").addClass('hide')
            });

            //insights edit toggle
            $doc.on('mouseover',"[data-action='edit-widget']",function() {
                $(this).find('.button-edit').removeClass('hide');
            });
            $doc.on('mouseout',"[data-action='edit-widget']",function() {
                $('.button-edit').addClass('hide');
            });
            $doc.on('click',".button-edit",function() {
              _this.editingWidgetId = $(this).attr('data-index');
              _this.editingIndex = $(this).parent().attr('data-index');
              
              _this.current_edit = {
                metric: $(this).attr('data-metric'),
                metric_type: $(this).attr('data-metric-type'),
                widget_type: $(this).attr('data-widget-type'),
              }
            });
            //insights save
            $doc.on('click',"#configure-insight-widget [data-submit='modal']",function(event) {
                event.preventDefault();
                _this.saveInsights();
            });

            //recent questions click
            $doc.on("click","[data-action='select-recent-question']",function() {

                var index = $(this).attr('data-index');
                var data = HelpdeskReports.locals.recent_questions[index];
                _this.last_question = data;
                $popover.hide();
                $selcted_queries.empty();
                $selcted_queries.html(data.markup);
                $input.attr('data-text','');
                if(data.markup == undefined) {
                    //populate search box
                    $input.val(data.text);
                }
                _this.fetchAnswer(data);
            })
        },
        init : function() {
            if(HelpdeskReports.locals.qna_feature_enabled) {
                HelpdeskReports.Qna_util.init();
            }
            this.bindEvents();
            if(HelpdeskReports.locals.insights_feature_enabled){
                this.fetchInsightConfig();
                this.fetchRecentQuestions();
            }
        }
    }
    return _FD;
})(jQuery);
