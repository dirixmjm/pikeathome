'use strict';

/* Services */
var depahServices = angular.module('depahServices', ['ngResource']);

depahServices.factory('Sensor', ['$resource',
  function($resource){
    return $resource('http://192.168.1.1:8000/testit.json?receiver=:ssmv&command=:command', {},
    {
      get: {method:'GET', params:{ssmv:'xiserver',command:'12'},isArray:true}
    });
  }]);
