require 'fileutils'
require 'open3'
require 'shellwords'

def exec_command(command)
  command = Shellwords.join(command)
  STDERR.puts command
  output, status = Open3.capture2(command)
  STDERR.puts output
  raise "command failed with exit code #{status}" unless status.success?
end

%i[go js ruby].each do |lang|
  repo_dir = "/tmp/results/aimastering-#{lang}"

  # git push
  Dir.chdir(repo_dir) do
    exec_command(%w[
                   git push origin master
                 ])
  end
end
