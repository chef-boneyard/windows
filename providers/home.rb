require 'chef/mixin/shell_out'
include Chef::Mixin::ShellOut

action :create do
  task_name = "create_#{@new_resource.name}_home"
  user_home = ::File.join(ENV['SYSTEMDRIVE'], 'Users', @new_resource.name)
    .gsub(::File::SEPARATOR, ::File::ALT_SEPARATOR)

  # Run whoami as scheduled task to get LocalServer group privilege:
  # SeAssignPrimaryTokenPrivilege (Replace a process-level token)
  if task_query(task_name).empty?
    cmd =  "schtasks /Create /TN \"#{task_name}\" "
    cmd += "/SC once /SD \"01/01/2003\" /ST \"00:00\" /TR \"whoami.exe\" "
    cmd += "/RU \"#{@new_resource.name}\" /RP \"#{@new_resource.password}\" "
    cmd += "/RL HIGHEST "
    shell_out!(cmd, {:returns => [0]})
  end

  unless ::File.exist?(user_home)
    shell_out!("schtasks /Run /TN \"#{task_name}\"", {:returns => [0]})
  end

  # wait until task completed
  loop { break unless task_status(task_name) == 'Running' }

  new_resource.updated_by_last_action true
  Chef::Log.info "#{user_home} created"
end

def task_query(task_name)
  shell_out("schtasks /Query /FO LIST /V /TN \"#{task_name}\"").stdout
end

def task_status(task_name)
  task = Hash.new
  task_query(task_name).split("\n").map! do |line|
    line.split(":", 2).map! do |field|
      field.strip
    end
  end.each do |field|
    if field.kind_of? Array and field[0].respond_to? :to_sym
      task[field[0].gsub(/\s+/,"").to_sym] = field[1]
    end
  end
  task[:Status]
end
