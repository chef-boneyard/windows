require 'chef/mixin/shell_out'
include Chef::Mixin::ShellOut

action :create do
  task_name = "build_#{new_resource.name}_home"
  user_home = ::File.join(ENV['SYSTEMDRIVE'], 'Users', new_resource.name)
              .gsub(::File::SEPARATOR, ::File::ALT_SEPARATOR)

  # Create whoami as scheduled task to get Local Server group privilege:
  # SeAssignPrimaryTokenPrivilege (Replace a process-level token)
  execute "create_#{task_name}_task" do
    command <<-EOF
schtasks /Create /TN "#{task_name}" /SC once /SD "01/01/2003" /ST "00:00" \
/TR "whoami.exe" /RU "#{new_resource.name}" /RP "#{new_resource.password}" \
/RL HIGHEST
EOF
    sensitive true
    only_if { task_query(task_name).empty? }
  end

  execute "run_#{task_name}_task" do
    command "schtasks /Run /TN \"#{task_name}\""
    not_if { ::File.exist?(user_home) }
  end

  ruby_block "wait_until_#{task_name}_task_completed" do
    block do
      sleep(1) until task_completed?(task_name)
    end
    action :run
  end

  execute "delete_#{task_name}_task" do
    command "schtasks /Delete /TN \"#{task_name}\" /F"
    not_if { task_query(task_name).empty? }
  end

  new_resource.updated_by_last_action true
  Chef::Log.info "#{user_home} created"
end

def task_query(task_name)
  shell_out("schtasks /Query /FO LIST /V /TN \"#{task_name}\"").stdout
end

def task_completed?(task_name)
  out = task_query(task_name)
  status = /^Status:(.*)$/.match(out).captures[0]
  status.strip == 'Ready'
end
