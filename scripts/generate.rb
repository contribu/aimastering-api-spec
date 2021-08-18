require 'fileutils'
require 'open3'
require 'shellwords'

def exec_command(command)
  command = Shellwords.join(command)
  warn command
  output, status = Open3.capture2(command)
  warn output
  raise "command failed with exit code #{status}" unless status.success?
end

config = {
  go: {
    language: 'go',
    additional_properties: {
      packageName: 'aimastering'
    },
    template: '/tmp/swagger-codegen/modules/swagger-codegen/src/main/resources/go'
  },
  js: {
    language: 'javascript',
    additional_properties: {
      projectName: 'aimastering',
      projectVersion: '1.1.0'
    }
  },
  ruby: {
    language: 'ruby',
    additional_properties: {
      gemName: 'aimastering',
      gemAuthor: 'Bakuage Co., Ltd.',
      gemHomepage: 'https://github.com/ai-mastering/aimastering-ruby',
      gemLicense: 'Apache 2.0',
      gemVersion: '1.1.0'
    }
  }
}

FileUtils.rm_rf('/tmp/swagger-codegen')
exec_command(%w[git clone -b feature/aimastering --depth 1 git@github.com:contribu/swagger-codegen.git
                /tmp/swagger-codegen])

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
  # docker -v option doesn't work in circleci
  # use docker cp

  api_spec_url = 'https://api.bakuage.com/api_spec.json'
  swagger_image = 'swaggerapi/swagger-codegen-cli:v2.3.1'
  # swagger_image = 'swaggerapi/swagger-codegen-cli:2.4.21'

  # with docker
  exec_command([
    'docker', 'create', '--name', 'swagger-codegen-cli',
    swagger_image,
    'generate',
    '-i', api_spec_url,
    '-l', config[lang][:language],
    config[lang][:template] ? ['-t', config[lang][:template]] : [],
    config[lang][:additional_properties].map do |key, value|
      [
        '--additional-properties',
        "#{key}=#{value}"
      ]
    end,
    '-o', '/tmp/out'
  ].flatten)
  exec_command(['docker', 'cp', '/tmp/swagger-codegen', 'swagger-codegen-cli:/tmp/swagger-codegen'])
  exec_command(['docker', 'start', '-a', 'swagger-codegen-cli'])
  exec_command(['docker', 'cp', 'swagger-codegen-cli:/tmp/out/.', repo_dir])
  exec_command(%w[docker rm swagger-codegen-cli])

  # without docker
  # exec_command([
  #   'java', '-jar', '/tmp/swagger-codegen-cli.jar',
  #   'generate',
  #   '-i', api_spec_url,
  #   '-l', config[lang][:language],
  #   config[lang][:template] ? ['-t', config[lang][:template]] : [],
  #   config[lang][:additional_properties].map do |key, value|
  #     [
  #       '--additional-properties',
  #       "#{key}=#{value}"
  #     ]
  #   end,
  #   '-o', repo_dir
  # ].flatten)

  # git commit if diff exists
  Dir.chdir(repo_dir) do
    exec_command([
                   'git', 'add', '.'
                 ])
    exec_command([
                   'bash', '-c',
                   ['git', 'diff-index', '--quiet', 'HEAD', '||',
                    'git', 'commit', '-m', '"Generated by CI"'].join(' ')
                 ])
  end
end
