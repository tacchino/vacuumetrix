#!/usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
require 'Sendit'
require 'rubygems'
require 'fog'
require 'json'

if ARGV.length != 1
  puts "I need one argument. The space separated Dynamo table names"
  exit 1
end

tables = ARGV[0].split(' ')

# 15 minutes back, 5 min period

startTime = Time.now.utc-3600
endTime  = Time.now.utc-3300

operations = %w(PutItem DeleteItem UpdateItem GetItem BatchGetItem Scan Query)
operationLevelMetrics = [
    {
        :name => "SuccessfulRequestLatency",
        :unit => "Milliseconds",
        :stats => ["Minimum", "Maximum", "Average"]
    },
    {
        :name => "ThrottledRequests",
        :unit => "Count",
        :stats => ["Sum"],
    },
    {
        :name => "SystemErrors",
        :unit => "Count",
        :stats => ["Sum"],
    }
]


cloudwatch = Fog::AWS::CloudWatch.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey)

tables.each do |table|
  operationLevelMetrics.each do |metric|
    metric[:stats].each do |stat|
      operations.each do |operation|
        response = cloudwatch.get_metric_statistics({
                                                      'Statistics' => stat,
                                                      'StartTime' => startTime.iso8601,
                                                      'EndTime' => endTime.iso8601,
                                                      'Period' => 300,
                                                      'Unit' => metric[:unit],
                                                      'MetricName' => metric[:name],
                                                      'Namespace' => 'AWS/DynamoDB',
                                                      'Dimensions' => [
                                                          {
                                                              'Name' => 'TableName',
                                                              'Value' => table
                                                          },
                                                          {
                                                              'Name' => "Operation",
                                                              'Value' => operation
                                                          }
                                                      ]
                                                  }).body['GetMetricStatisticsResult']['Datapoints']

        metricpath = "AWScloudwatch.Dynamo." + table + "." + metric[:name] + "." + operation + "." + stat
        begin
          metricvalue = response.first[stat]
        rescue
          metricvalue = 0
        end
        metrictimestamp = endTime.to_i.to_s

        Sendit metricpath, metricvalue, metrictimestamp
        puts metricpath, metricvalue, metrictimestamp
      end
    end
  end
end

tableLevelMetrics = [
    {
        :name => "SystemErrors",
        :unit => "Count",
        :stats => ["Sum"],
    },
    {
        :name => "ProvisionedReadCapacityUnits",
        :unit => "Count",
        :stats => ["Average"],
    },
    {
        :name => "ProvisionedWriteCapacityUnits",
        :unit => "Count",
        :stats => ["Average"],
    },
    {
        :name => "ConsumedReadCapacityUnits",
        :unit => "Count",
        :stats => ["Minimum", "Maximum", "Average", "Sum"],
    },
    {
        :name => "ConsumedWriteCapacityUnits",
        :unit => "Count",
        :stats => ["Minimum", "Maximum", "Average", "Sum"],
    },
    {
        :name => "ReturnedItemCount",
        :unit => "Count",
        :stats => ["Minimum", "Maximum", "Average", "Sum"],
    }
]

tables.each do |table|
  tableLevelMetrics.each do |metric|
    metric[:stats].each do |stat|
      response = cloudwatch.get_metric_statistics({
                                                      'Statistics' => stat,
                                                      'StartTime' =>  startTime.iso8601,
                                                      'EndTime'    => endTime.iso8601,
                                                      'Period'     => 300,
                                                      'Unit'       => metric[:unit],
                                                      'MetricName' => metric[:name],
                                                      'Namespace'  => 'AWS/DynamoDB',
                                                      'Dimensions' => [{
                                                                           'Name'  => 'TableName',
                                                                           'Value' => table
                                                                       }]
                                                  }).body['GetMetricStatisticsResult']['Datapoints']

      metricpath = "AWScloudwatch.Dynamo." + table + "." + metric[:name] + "." + stat
      begin
        metricvalue = response.first[stat]
      rescue
        metricvalue = 0
      end
      metrictimestamp = endTime.to_i.to_s

      Sendit metricpath, metricvalue, metrictimestamp
      puts metricpath, metricvalue, metrictimestamp
    end

  end
end