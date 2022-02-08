# frozen_string_literal: true

require 'fileutils'
require_relative 'github_api'

module CreateMSYS2Tools
  class << self

    include GitHubAPI

    MSYS2_ROOT = 'C:/msys64'
    TEMP = ENV.fetch('RUNNER_TEMP') { ENV.fetch('RUNNER_WORKSPACE') { ENV['TEMP'] } }
    ORIG_MSYS2 = "#{TEMP}/msys64".gsub '\\', '/'

    SYNC = 'var/lib/pacman/sync'
    LOCAL = 'var/lib/pacman/local'

    SEVEN = 'C:\Program Files\7-Zip\7z'

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
      time = Time.now.utc.strftime '%Y-%m-%d %H:%M:%S UTC'

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
        resp_obj = v3_get http, USER_REPO, "releases/tags/#{TAG}"
        body = resp_obj['body']
        id   = resp_obj['id']

        h = { 'body' => new_body(body, 'msys2', time, BUILD_NUMBER) }
        v3_patch http, USER_REPO, "releases/#{id}", h
      end
    end

    def new_body(old_body, name, time, build_number)
      old_body.sub(/(^\| +\*\*#{name}\*\* +\|).+/) {
        "#{$1} #{time} | #{build_number.rjust 6} |"
      }
    end
  end
end

CreateMSYS2Tools.run
