#
# Cookbook:: nessus_agent
# Recipe:: default
#
# Copyright:: 2020, Keith Walker, All Rights Reserved.

require 'mixlib/shellout'

linking_key = 'your_linking_key'
agent_name = node['hostname']
agent_groups = 'chef_test_group'


# Platform specific settings
case node['platform']
  when 'redhat'
    architecture = 'x86_64'
    case node['platform_version'].split('.')[0]
      when '6'
        operating_system_name = 'es6'
      when '7'
        operating_system_name = 'es7'
    end  
  when 'amazon'
    operating_system_name = 'amzn'
	architecture = 'x86_64'
  when 'ubuntu'
    architecture = 'amd64'
    operating_system_name = 'ubuntu1110'
  when 'debian'
    architecture = 'amd64'
    operating_system_name = 'debian'
  when 'suse'
    architecture = 'x86_64'
	case node['platform_version'].split('.')[0]
      when '11'
        operating_system_name = 'suse11'
      when '12'
        operating_system_name = 'suse12'
    end
end

gpg_key_length = '2048'

nessus_api_url = 'https://www.tenable.com/downloads/api/v1/public/pages/nessus-agents'
agreement_query_string = '?i_agree_to_tenable_license_agreement=true'

yum_dependencies_list = ['jq']

yum_package 'yum_dependencies' do
  package_name yum_dependencies_list
  action :upgrade
end

find_agent_download_id_command = 'curl -s ' + nessus_api_url + agreement_query_string + '|jq \'.downloads[]|select(.file |contains("' + architecture + '"))| select(.file |contains("' + operating_system_name + '"))| .id\''
find_agent_download_id = Mixlib::ShellOut.new(find_agent_download_id_command)
find_agent_download_id.run_command
agent_tenable_download_id = find_agent_download_id.stdout.strip


find_gpg_download_id_command = 'curl -s ' + nessus_api_url + agreement_query_string + '|jq \'.downloads[]|select(.file |contains("gpg"))| select(.file |contains("' + gpg_key_length + '"))| .id\''
find_gpg_download_id = Mixlib::ShellOut.new(find_gpg_download_id_command)
find_gpg_download_id.run_command
gpg_key_tenable_download_id = find_gpg_download_id.stdout.strip

gpg_key_url = nessus_api_url + '/downloads/' + gpg_key_tenable_download_id + '/download' + agreement_query_string

working_dir='/tmp/'

execute 'download_gpg_key' do
  command 'wget -O tenable-2048.gpg ' + gpg_key_url
  cwd working_dir
  creates 'tenable-2048.gpg'
end

execute 'install_gpg_key' do
  command 'rpm --import ' + working_dir + 'tenable-2048.gpg'
end

nessus_agent_url = nessus_api_url + '/downloads/' + agent_tenable_download_id + '/download' + agreement_query_string

execute 'download_nessus_agent' do
  command 'wget -O nessus_agent_latest.rpm ' + nessus_agent_url
  cwd working_dir
  creates 'nessus_agent_latest.rpm'
end

rpm_package 'install_nessus-agent' do
  allow_downgrade false
  package_name 'NessusAgent'
  source working_dir + 'nessus_agent_latest.rpm'
  action :upgrade
end

service 'nessusagent' do
  action [:start]
end

link_command = '/opt/nessus_agent/sbin/nessuscli agent link --key=' + linking_key
link_command += ' --name='
link_command += agent_name 
link_command += ' --groups="'
link_command += agent_groups
link_command += '"'
link_command += ' --cloud'

execute 'activate_nessus_agent' do
  command link_command
  #not_if '/opt/nessus_agent/sbin/nessuscli agent status'
end
