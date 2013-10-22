#
# Cookbook Name:: bcpc
# Library:: utils
#
# Copyright 2013, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'openssl'
require 'thread'

def init_config
  if not Chef::DataBag.list.key?('configs')
    puts "************ Creating data_bag \"configs\""
    bag = Chef::DataBag.new
    bag.name("configs")
    bag.save
  end
  begin
    $dbi = data_bag_item("configs", node.chef_environment)
    puts "============ Loaded existing data_bag_item \"configs/#{node.chef_environment}\""
  rescue
    $dbi = Chef::DataBagItem.new
    $dbi.data_bag("configs")
    $dbi.raw_data = { "id" => node.chef_environment }
    $dbi.save
    puts "++++++++++++ Created new data_bag_item \"configs/#{node.chef_environment}\""
  end
end

def make_config(key, value)
  init_config if $dbi.nil?
  if $dbi[key].nil?
    $dbi[key] = value
    $dbi.save
    puts "++++++++++++ Creating new item with key \"#{key}\""
    return value
  else
    puts "============ Loaded existing item with key \"#{key}\""
    return $dbi[key]
  end
end

def get_config(key)
  init_config if $dbi.nil?
  puts "------------ Fetching value for key \"#{key}\""
  return $dbi[key]
end

def get_all_nodes
  results = search(:node, "role:BCPC* AND chef_environment:#{node.chef_environment}")
  if results.any?{|x| x.hostname == node.hostname}
    results.map!{|x| x.hostname == node.hostname ? node : x}
  else
    results.push(node)
  end
  return results
end

def get_head_nodes
  results = search(:node, "role:BCPC-Headnode AND chef_environment:#{node.chef_environment}")
  results.map!{ |x| x.hostname == node.hostname ? node : x }
  return (results == []) ? [node] : results
end

def get_hadoop_heads
  results = search(:node, "(role:BCPC-Hadoop-Head OR role:BCPC-Hadoop-Standby) AND chef_environment:#{node.chef_environment}")
  if results.any?{|x| x.hostname == node.hostname}
    results.map!{|x| x.hostname == node.hostname ? node : x}
  else
    results.push(node) if node[:roles].include? "BCPC-Hadoop-Head"
  end
  return results
end

def get_quorum_hosts
  results = search(:node, "(role:BCPC-Hadoop-Quorumnode OR role:BCPC-Hadoop-Standby OR role:BCPC-Hadoop-Head) AND chef_environment:#{node.chef_environment}")
  if results.any?{|x| x.hostname == node.hostname}
    results.map!{|x| x.hostname == node.hostname ? node : x}
  else
    results.push(node) if node[:roles].include? "BCPC-Hadoop-Quorumnode"
  end
  return results
end

def get_hadoop_workers
  results = search(:node, "role:BCPC-Hadoop-Worker AND chef_environment:#{node.chef_environment}")
  if results.any?{|x| x.hostname == node.hostname}
    results.map!{|x| x.hostname == node.hostname ? node : x}
  else
    results.push(node) if node[:roles].include? "BCPC-Hadoop-Worker"
  end
  return results
end

def secure_password
  pw = String.new
  while pw.length < 20
    pw << ::OpenSSL::Random.random_bytes(1).gsub(/\W/, '')
  end
  pw
end

def float_host(*args)
  "f-" + args.join('.')
end

def storage_host(*args)
  "s-" + args.join('.')
end
