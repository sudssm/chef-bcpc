#
# Cookbook Name:: bcpc
# Recipe:: sahara
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

include_recipe "bcpc::apache2"

apt_package "libmysqlclient-dev" do
    action :install
end

apt_package "python-mysqldb" do
    action :install
end

apt_package "python-dev" do
    action :install
end

apt_package "libxml2-dev" do
    action :install
end

apt_package "libxslt1-dev" do
    action :install
end

apt_package "python-virtualenv" do
    action :install
end

ruby_block "initialize-sahara-config" do
    block do
        make_config('mysql-sahara-user', "sahara")
        make_config('mysql-sahara-password', secure_password)
    end
end

python_virtualenv "/home/ubuntu/sahara-venv" do 
    owner "ubuntu"
    group "ubuntu"
    action :create
end

python_pip "MySQL-python" do
    virtualenv "/home/ubuntu/sahara-venv"
    action :install
end

python_pip "http://tarballs.openstack.org/sahara/sahara-master.tar.gz" do
    virtualenv "/home/ubuntu/sahara-venv"
    action :install
end

directory "/etc/sahara" do 
    owner "root"
    group "root"
    mode 00600
    action :create
end

directory "/var/log/sahara" do
    owner "root"
    group "root"
    mode 00600
    action :create
end


template "/etc/sahara/sahara.conf" do
    source "sahara.conf.erb"
    owner "root"
    group "root"
    mode 00600
end

ruby_block "sahara-database-creation" do
    block do
    if not system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['sahara_dbname']}\"'|grep \"#{node['bcpc']['sahara_dbname']}\"" then
            %x[ mysql -uroot -p#{get_config('mysql-root-password')} -e "CREATE DATABASE #{node['bcpc']['sahara_dbname']};"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['sahara_dbname']}.* TO '#{get_config('mysql-sahara-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-sahara-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['sahara_dbname']}.* TO '#{get_config('mysql-sahara-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-sahara-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "FLUSH PRIVILEGES;"
            ]
            self.notifies :run, "bash[sahara-database-sync]", :immediately
            self.resolve_notification_references
        end
    end
end

bash "sahara-database-sync" do
    action :nothing
    user "root"
    code "/home/ubuntu/sahara-venv/bin/sahara-db-manage --config-file /etc/sahara/sahara.conf upgrade head"
end

bash "sahara-start" do
    action :nothing
    user "root"
    code "/home/ubuntu/sahara-venv/bin/sahara-all --config-file /etc/sahara/sahara.conf"
end
