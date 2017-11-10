module Qc
  class CommandRunner
    DEFAULT_FILE_EXTENSIONS = 'cs,py'

    SUPPORTED_COMMANDS =%i(login logout init push)

    attr_reader :quant_connect_proxy
    attr_accessor :project_settings

    def initialize(quant_connect_proxy)
      @quant_connect_proxy = quant_connect_proxy
      @project_settings = read_project_settings
    end

    def run(command)
      if command == :login
        do_run(command)
      else
        require_login do
          do_run(command)
        end
      end
    end

    def run_default
      run(:default)
    end

    private

    def credentials
      quant_connect_proxy&.credentials
    end

    def read_project_settings
      if ::File.exist?(project_settings_file)
        YAML.load(::File.open(project_settings_file))
      else
        Qc::ProjectSettings.new
      end
    end

    def logged_in?
      puts "VALUE: #{!!credentials}"
      !!credentials
    end

    def require_login
      if credentials
        yield
      else
        puts "Please sign in by executing 'qc login' first"
        false
      end
    end

    def do_run(command)
      case command
        when :default
          puts "Default command not implemented yet..."
          true
        when *SUPPORTED_COMMANDS
          send "run_#{command}"
        else
          raise "Unknonw command '#{command}'. Supported commands: #{SUPPORTED_COMMANDS.collect(&:to_s).join(', ')}"
      end
    end

    def run_login
      puts "Please introduce your QuantConnect API credentials. You can find them in your preferences in https://www.quantconnect.com/account."
      user_id = ask_for_value 'User id:'
      access_token = ask_for_value 'Access token:'

      quant_connect_proxy.credentials = Qc::Credentials.new(user_id, access_token)

      if quant_connect_proxy.valid_login?
        Qc::Credentials.new(user_id, access_token).save_to_home
        true
      else
        puts "Invalid credentials"
        false
      end
    end

    def run_init
      FileUtils.mkdir_p(Qc::Util.project_dir)
      project = ask_for_project
      self.project_settings.project_id = project.id
      self.project_settings.file_extensions = ask_for_extensions
      save_project_settings
    end

    def save_project_settings
      ::File.open(project_settings_file, 'w') {|file| file.write self.project_settings.to_yaml}
    end

    def project_settings_file
      ::File.join(Qc::Util.project_dir, 'settings.yml')
    end

    def ask_for_value(question)
      puts question
      v = STDIN.gets
      v.chomp
    end

    def ask_for_project
      puts "Fetching projets from Quantconnect..."
      projects = quant_connect_proxy.list_projects
      puts "Select the project you want to associate with this directory"
      projects.each.with_index do |project, index|
        puts "[#{index+1}] - #{project.name}"
      end
      index = ask_for_value "Project number?"
      index = index.to_i
      if index >=1 && index < projects.length + 1
        projects[index-1]
      else
        puts "Invalid value (please type a number between #{1} and #{projects.length})"
        ask_for_project
      end
    end

    def ask_for_extensions
      file_extensions = ask_for_value "Introduce the file extensions you want to send to QuantConnect as a comma separated list. ENTER to default '#{DEFAULT_FILE_EXTENSIONS}'"
      file_extensions = DEFAULT_FILE_EXTENSIONS if file_extensions.empty?
      file_extensions
    end

    def run_logout
      credentials.destroy
      puts "Logged out successfully"
      true
    end

    def run_push
      Dir["*.{#{project_settings.file_extensions}}"].each do |file|
        puts "uploading #{file}..."
        content = ::File.read file
        quant_connect_proxy.put_file project_settings.project_id, file, content
      end
    end
  end
end