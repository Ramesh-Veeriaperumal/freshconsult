/*jslint browser:true */
/*global App */

/*
 * skills.js
 * author: Rajasegar
 */

window.App = window.App || {};
window.App.Admin = window.App.Admin || {};
(function($){
    'use strict';

    App.Admin.Skills = {
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
              case 'admin/skills/index':
                  this.currentModule = 'Index';
                  break;
              case 'admin/skills/new':
                  this.currentModule = 'New';
                  break;
              case 'admin/skills/edit':
                  this.currentModule = 'Edit';
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
