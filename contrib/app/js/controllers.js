'use strict';

/* Controllers */
var depahControllers = angular.module('depahControllers', []);

depahControllers.controller('SensorListCtrl', ['$scope', 'Sensor',
  function($scope, Sensor) {
    $scope.sensors = Sensor.get({},function(sensors) {
    $scope.sensorFirst = sensors[0].name;
    }, function(errorResult) {
       console.debug(errorResult);
    });
    $scope.orderProp = 'name';
    $scope.setClick = function(name) {
     $scope.doClick = 'true';
     }
  }]);

depahControllers.controller('SensorDetailCtrl',['$scope', '$routeParams', 'Sensor',
  function($scope, $routeParams, Sensor) {
    $scope.variables = Sensor.query({ssmv:$routeParams.sensorId ,command:'2'});
  }]);

depahControllers.controller('GetValue',['$scope', 'Sensor',
  function($scope, Sensor) {
    $scope.variables = Sensor.query({ssmv:'xiserver.PlugWise.Diepvries' ,command:'2'});
  }]);
