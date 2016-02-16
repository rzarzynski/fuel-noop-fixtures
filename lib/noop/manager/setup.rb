module Noop
  class Manager

    def dir_path_gem_home
      return Pathname.new ENV['GEM_HOME'] if ENV['GEM_HOME']
      dir_name_bundle = Pathname.new 'bundled_gems'
      Noop::Config.dir_path_workspace + dir_name_bundle
    end

    def bundle_installed?
      `bundle --version`
      $?.exitstatus == 0
    end

    def librarian_installed?
      `librarian-puppet version`
      $?.exitstatus == 0
    end

    def setup_bundle
      ENV['GEM_HOME'] = dir_path_gem_home.to_s
      Dir.chdir Noop::Config.dir_path_root
      bundle_install_and_update
      Dir.chdir Noop::Config.dir_path_deployment
      bundle_install_and_update
      Dir.chdir Noop::Config.dir_path_root
    end

    def setup_library
      ENV['GEM_HOME'] = dir_path_gem_home.to_s
      Dir.chdir Noop::Config.dir_path_deployment
      update_puppet_modules
      Dir.chdir Noop::Config.dir_path_root
    end

    def bundle_install_and_update
      Noop::Utils.error 'Bundle is not installed!' unless bundle_installed?
      Noop::Utils.debug "Starting 'bundle install' in the Gem home: #{ENV['GEM_HOME']}"
      Noop::Utils.run 'bundle install'
      Noop::Utils.error 'Could not prepare bundle environment!' if $?.exitstatus != 0
      Noop::Utils.debug "Starting 'bundle update' in the Gem home: #{ENV['GEM_HOME']}"
      Noop::Utils.run 'bundle update'
      Noop::Utils.error 'Could not update bundle environment!' if $?.exitstatus != 0
    end

    # run librarian-puppet to fetch modules as necessary
    def update_puppet_modules
      Noop::Utils.error 'Puppet Librarian is not installed!' unless librarian_installed?
      command = './update_modules.sh -v'
      command = command + ' -b' if options[:bundle_exec]
      command = command + ' -r' if options[:reset_librarian_puppet]

      Noop::Utils.debug 'Starting update_modules script'
      Noop::Utils.run command
      Noop::Utils.error 'Unable to update upstream puppet modules using librarian-puppet!' if $?.exitstatus != 0
      Noop::Utils.debug 'Finished update_modules script'
    end

  end
end