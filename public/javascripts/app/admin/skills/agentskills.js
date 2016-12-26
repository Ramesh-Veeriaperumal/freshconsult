/*jslint browser:true */
/*global App */

/*
 * skills.js
 * author: Siwalik
 */

window.App = window.App || {};
window.App.Admin = window.App.Admin || {};
(function($){
    'use strict';

    App.Admin.AgentSkills = {
        currentModule: '',

        onFirstVisit: function(data){
            this.onVisit(data);
        },

        onVisit: function(data) {
            this.setSubModule();
            if(this.currentModule !== ''){
                this[this.currentModule].onVisit();
            }
        },

        setSubModule: function(data){
            switch(App.namespace){
              case 'admin/user_skills/index':
                  this.currentModule = 'Index';
                  break;
              default:
                  break;
            }
        },

        onLeave: function(data){
            if(this.currentModule !== ''){
                this[this.currentModule].onLeave();
                this.currentModule = '';
            }
        }
    };
    
}(window.jQuery));
