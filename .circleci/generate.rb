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

config = {
  go: {
    language: 'go',
    additional_properties: {
      packageName: 'aimastering'
    }
  },
  js: {
    language: 'javascript',
    additional_properties: {
      projectName: 'aimastering'
    }
  },
  ruby: {
    language: 'ruby',
    additional_properties: {
      gemName: 'aimastering',
      gemAuthor: 'Bakuage Co., Ltd.',
      gemHomepage: 'https://github.com/ai-mastering/aimastering-ruby',
      gemLicense: 'Apache 2.0'
    }
  }
}

%i[go js ruby].each do |lang|
  repo_dir = "/tmp/results/aimastering-#{lang}"

  # git clone
  exec_command([
                 'git', 'clone',
                 "git@github.com:ai-mastering/aimastering-#{lang}.git",
                 repo_dir
               ])
  Dir.glob("#{repo_dir}/*").each do |path|
    FileUtils.rm_rf(path)
  end

  # generate
  exec_command([
    'docker', 'run', '--rm',
    '-v', '/tmp/results:/local',
    'swaggerapi/swagger-codegen-cli',
    'generate',
    '-i', 'https://bakuage.com/api/api_spec.json',
    '-l', config[lang][:language],
    config[lang][:additional_properties].map do |key, value|
      [
        '--additional-properties',
        "#{key}=#{value}"
      ]
    end,
    '-o', "/local/aimastering-#{lang}"
  ].flatten)

  # git commit
  Dir.chdir(repo_dir) do
    exec_command([
                   'git', 'add', '.'
                 ])
    exec_command([
                   'git', 'commit', '-m', 'Generated by CI'
                 ])
  end
end