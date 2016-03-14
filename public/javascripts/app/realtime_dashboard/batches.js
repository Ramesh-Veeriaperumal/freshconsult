/*jslint browser: true, devel: true */
/*global  App:true */

DataStore = DataStore || {};

(function ($) {
    "use strict";
    var badges = [
        { "name" : "Support hero",      "classname" : "badges-a-small-call",          "id" :  1 },
        { "name" : "Explorer",          "classname" : "badges-a-small-elephant",      "id" :  2 },
        { "name" : "Social supporter",  "classname" : "badges-small-fb",              "id" :  3 },
        { "name" : "Zeus",              "classname" : "badges-small-fcr",             "id" :  4 },
        { "name" : "Commentor",         "classname" : "badges-small-forum",           "id" :  5 },
        { "name" : "Heart",             "classname" : "badges-small-love",            "id" :  6 },
        { "name" : "Local",             "classname" : "badges-a-small-priority",      "id" :  7 },
        { "name" : "The fixer",         "classname" : "badges-small-settings",        "id" :  8 },
        { "name" : "Bulls eye",         "classname" : "badges-small-shooter",         "id" :  9 },
        { "name" : "Smile collector",   "classname" : "badges-a-smiley",              "id" : 10 },
        { "name" : "Timekeeper",        "classname" : "badges-small-time",            "id" : 11 },
        { "name" : "Champion",          "classname" : "badges-small-trophy",          "id" : 12 },
        { "name" : "Super commentor",   "classname" : "badges-small-forum-comment",   "id" : 13 },
        { "name" : "Guest of honor",    "classname" : "badges-small-winner",          "id" : 14 },
        { "name" : "Banker",            "classname" : "badges-a-small-money",         "id" : 15 },
        { "name" : "Perfectionist",     "classname" : "badges-a-small-glasses",       "id" : 16 },
        { "name" : "Bibliophile",       "classname" : "badges-a-small-closed-book",   "id" : 17 },
        { "name" : "Druid",             "classname" : "badges-a-small-experiment",    "id" : 18 },
        { "name" : "Statistician",      "classname" : "badges-a-small-chart",         "id" : 19 },
        { "name" : "Sweet-tooth",       "classname" : "badges-a-small-cake",          "id" : 20 },
        { "name" : "Socialite",         "classname" : "badges-a-small-martini",       "id" : 21 },
        { "name" : "Rocket scientist",  "classname" : "badges-a-small-rocket",        "id" : 22 },
        { "name" : "Anchor",            "classname" : "badges-a-small-sailor",        "id" : 23 },
        { "name" : "Ace",               "classname" : "badges-a-small-spade",         "id" : 24 },
        { "name" : "Speed eater",       "classname" : "badges-small-gamer",           "id" : 25 },
        { "name" : "Night owl",         "classname" : "badges-a-small-late-worker",   "id" : 26 },
        { "name" : "Gentleman",         "classname" : "badges-small-the-professional","id" : 27 },
        { "name" : "Traveller",         "classname" : "badges-a-small-traveller",     "id" : 28 },
        { "name" : "Writer",            "classname" : "badges-small-writer",          "id" : 29 },
        { "name" : "Performer",         "classname" : "badges-a-small-performer",     "id" : 30 },
        { "name" : "Best seller",       "classname" : "badges-small-open-book",       "id" : 31 },
        { "name" : "Tweet supporter",   "classname" : "badges-small-tweet",           "id" : 32 },
        { "name" : "Bomber man",        "classname" : "badges-a-small-radiation",     "id" : 33 },
        { "name" : "Striker",           "classname" : "badges-a-small-player",        "id" : 34 },
        { "name" : "Conversationalist", "classname" : "badges-a-small-messenger",     "id" : 35 },
        { "name" : "The Diamond",       "classname" : "badges-a-small-diamond",       "id" : 36 },
        { "name" : "Super writer",      "classname" : "badges-small-scribe",          "id" : 37 },
        { "name" : "Lucky clover",      "classname" : "badges-a-small-clover",        "id" : 38 },
        { "name" : "Gameboy",           "classname" : "badges-small-joystick",        "id" : 39 },
        { "name" : "Beacon",            "classname" : "badges-a-small-lamp",          "id" : 40 },
        { "name" : "Flag bearer",       "classname" : "badges-a-small-flag",          "id" : 41 },
        { "name" : "Cafeholic",         "classname" : "badges-a-small-coffee",        "id" : 42 }, 
        { "name" : "Bureaucrat",        "classname" : "badges-a-small-business-man",  "id" : 43 },
        { "name" : "Artist",            "classname" : "badges-a-small-artist",        "id" : 44 },
        { "name" : "Minute-man",        "classname" : "badges-a-small-calendar",      "id" : 45 }
    ]

    DataStore.set('badges', badges);

}(window.jQuery));
