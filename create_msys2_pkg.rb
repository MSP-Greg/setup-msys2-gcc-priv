# frozen_string_literal: true

require 'fileutils'
require_relative 'common'

module CreateMSYS2Tools
  class << self

    include Common

    MSYS2_ROOT = 'C:/msys64'
    TEMP = ENV.fetch('RUNNER_TEMP') { ENV.fetch('RUNNER_WORKSPACE') { ENV['TEMP'] } }
    ORIG_MSYS2 = "#{TEMP}/msys64".gsub '\\', '/'

    SYNC = 'var/lib/pacman/sync'
    LOCAL = 'var/lib/pacman/local'

    def update_msys2
      msys_path = "#{MSYS2_ROOT}/usr/bin"

      exit(1) unless system "#{msys_path}/sed -i 's/^CheckSpace/#CheckSpace/g' C:/msys64/etc/pacman.conf"

      STDOUT.syswrite "\n#{YEL}#{LINE} Updating all installed packages#{RST}\n"
      exit(1) unless system "#{msys_path}/pacman.exe -Syuu  --noconfirm'"
      system 'taskkill /f /fi "MODULES eq msys-2.0.dll"'

      STDOUT.syswrite "\n#{YEL}#{LINE} Updating all installed packages (2nd pass)#{RST}\n"
      exit(1) unless system "#{msys_path}/pacman.exe -Syuu  --noconfirm'"
      system 'taskkill /f /fi "MODULES eq msys-2.0.dll"'

      pkgs = 'autoconf-wrapper autogen automake-wrapper bison diffutils libtool m4 make patch texinfo texinfo-tex compression'
      STDOUT.syswrite "\n#{YEL}#{LINE} Install MSYS2 packages#{RST}\n#{YEL}#{pkgs}#{RST}\n"
      exit(1) unless system "#{msys_path}/pacman.exe -S --noconfirm --needed --noprogressbar #{pkgs}"
    end

    def remove_non_msys2
      dirs = %w[clang32 clang64 clangarm64 mingw32 mingw64 ucrt64]
      Dir.chdir MSYS2_ROOT do |d|
        dirs.each { |dir_name| FileUtils.rm_rf dir_name }
      end

      dir = "#{MSYS2_ROOT}/#{LOCAL}"
      Dir.chdir dir do |d|
        del_dirs = Dir['mingw*']
        del_dirs.each { |dir_name| FileUtils.rm_rf dir_name }
      end
    end

    # remove files from 7z that are identical to Windows image
    def remove_duplicate_files
      files = Dir.glob('**/*', base: MSYS2_ROOT).reject { |fn| fn.start_with? LOCAL }

      removed_files = 0

      Dir.chdir MSYS2_ROOT do |d|
        files.each do |fn|
          old_fn = "#{ORIG_MSYS2}/#{fn}"
          if File.exist?(old_fn) && File.mtime(fn) == File.mtime(old_fn)
            removed_files += 1
            File.delete fn
          end
        end
      end
      puts "Removed #{removed_files} files"
    end

    # remove unneeded database files
    def clean_database(pre)
      dir = "#{MSYS2_ROOT}/#{SYNC}"
      files = Dir.glob('*', base: dir).reject { |fn| fn.start_with? pre }
      Dir.chdir(dir) do
        files.each { |fn| File.delete fn }
      end
    end

    def run
      current_pkgs = %x[#{MSYS2_ROOT}/usr/bin/pacman.exe -Q]
        .lines.reject { |l| l.start_with? 'mingw-w64-' }

      update_msys2

      updated_pkgs = %x[#{MSYS2_ROOT}/usr/bin/pacman.exe -Q]
        .lines.reject { |l| l.start_with? 'mingw-w64-' }

      time = Time.now.utc.strftime '%Y-%m-%d %H:%M:%S UTC'

      log_array_2_column updated_pkgs.map { |el| el.strip }, 48, "Installed MSYS2 Packages"

      if current_pkgs == updated_pkgs
        STDOUT.syswrite "\n** No update to MSYS2 tools needed **\n\n"
        exit 0
      end

      remove_non_msys2
      remove_duplicate_files
      clean_database 'msys'

      # create 7z file
      tar_path = "#{Dir.pwd}\\msys2.7z".gsub '/', '\\'
      Dir.chdir MSYS2_ROOT do
        system "\"#{SEVEN}\" a #{tar_path}"
      end

      # upload release asset using 'GitHub CLI'
      unless system("gh release upload #{TAG} msys2.7z --clobber")
        STDOUT.syswrite "\nUpload of new release asset failed!\n"
        exit 1
      end

      # update package info in release notes
      gh_api_http do |http|
        resp_obj = gh_api_v3_get http, USER_REPO, "releases/tags/#{TAG}"
        body = resp_obj['body']
        id   = resp_obj['id']

        h = { 'body' => update_release_notes(body, 'msys2', time, BUILD_NUMBER) }
        gh_api_v3_patch http, USER_REPO, "releases/#{id}", h
      end
    end

    def exec_check(msg, cmd)
      STDOUT.syswrite "\n#{YEL}#{LINE} #{msg}#{RST}\n"
      exit 1 unless system cmd
    end
  end
end

CreateMSYS2Tools.run
