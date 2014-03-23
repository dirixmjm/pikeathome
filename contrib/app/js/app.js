'use strict';

/* App Module */
var DePAHApp = angular.module('DePAHApp', [
  'ngRoute',
  'depahControllers',
  'depahServices'
]);

DePAHApp.config(['$routeProvider',
  function($routeProvider) {
    $routeProvider.
      when('/main', {
        templateUrl: 'partials/sensor-list.html',
        controller: 'SensorListCtrl'
      }).
      when('/main/:sensorId', {
        templateUrl: 'partials/sensor-detail.html',
        controller: 'SensorDetailCtrl'
      }).
      otherwise({
         redirectTo: '/main'
      });
  }]);

