#
# Cookbook Name:: hadoop_mapr
# Recipe:: default
#
# Copyright © 2013-2015 Cask Data, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe 'java::default'

include_recipe 'hadoop_mapr::repo'
include_recipe 'hadoop_mapr::_system_tuning'

# Create target install dir
directory node['hadoop_mapr']['install_dir'] do
  action :create
  recursive true
end

# Symlink alternate mapr base install dir
unless node['hadoop_mapr']['install_dir'] == '/opt/mapr'
  # Fail if /opt/mapr already exists since we can't replace it with a symlink
  if ::File.directory?('/opt/mapr') && !::File.symlink?('/opt/mapr')
    Chef::Application.fatal!("Cannot install to #{node['hadoop_mapr']['install_dir']} since previous installation exists in /opt/mapr")
  end

  # Symlink /opt/mapr
  link '/opt/mapr' do
    to node['hadoop_mapr']['install_dir']
  end
end

# Create 'mapr' user/group
if node['hadoop_mapr']['create_mapr_user'].to_s == 'true'
  # create 'mapr' group
  group node['hadoop_mapr']['mapr_user']['group'] do
    gid node['hadoop_mapr']['mapr_user']['gid']
    action :create
  end

  # create 'mapr' user
  user node['hadoop_mapr']['mapr_user']['username'] do
    uid node['hadoop_mapr']['mapr_user']['uid']
    gid node['hadoop_mapr']['mapr_user']['gid']
    password node['hadoop_mapr']['mapr_user']['password']
    action :create
  end
end

# Set hadoop.tmp.dir
hadoop_tmp_dir =
  if node['hadoop'].key?('core_site') && node['hadoop']['core_site'].key?('hadoop.tmp.dir')
    node['hadoop']['core_site']['hadoop.tmp.dir']
  else
    'file:///tmp/hadoop-${user}'
  end

node.default['hadoop']['core_site']['hadoop.tmp.dir'] = hadoop_tmp_dir

if node['hadoop']['core_site']['hadoop.tmp.dir'] == 'file:///tmp/hadoop-${user}'
  directory "/tmp/hadoop-#{node['hadoop_mapr']['mapr_user']['username']}" do
    mode '1777'
    owner node['hadoop_mapr']['mapr_user']['username']
    group node['hadoop_mapr']['mapr_user']['group']
    action :create
    recursive true
  end
elsif node['hadoop']['core_site']['hadoop.tmp.dir'] =~ /${user}/
  # Since we're creating a 1777 directory, Hadoop can create the user-specific subdirectories, itself
  directory File.dirname(hadoop_tmp_dir.gsub('file://', '')) do
    mode '1777'
    action :create
    recursive true
  end
else
  directory hadoop_tmp_dir.gsub('file://', '') do
    mode '1777'
    action :create
    recursive true
  end
end # End hadoop.tmp.dir
