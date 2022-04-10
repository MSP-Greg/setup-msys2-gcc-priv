# frozen_string_literal: true

# Original code by MSP-Greg
# This script creates 7z files of the mingw64 and ucrt64 MSYS2 gcc tool chains
# for use with GitHub Actions.  Since these files are installed on the Actions
# Windows runner's hard drive, smaller zip files speed up the installation.
# Hence, many of the 'doc' related files in the 'share' folder are removed.

require 'fileutils'
require_relative 'common'

module CreateMingwGCC
  class << self

    include Common

    TAR_DIR = "#{TEMP}/msys64"

    SYNC  = 'var/lib/pacman/sync'
    LOCAL = 'var/lib/pacman/local'

    PKG_NAME, PKG_PRE =
      case ARGV[0].downcase
      when 'ucrt64'
        ['ucrt64', 'mingw-w64-ucrt-x86_64-']
      when 'mingw64'
        ['mingw64', 'mingw-w64-x86_64-']
      when 'mingw32'
        ['mingw32', 'mingw-w64-i686-']
      else
        STDOUT.syswrite "Invalid package type, must be ucrt64, mingw64, or mingw32\n"
        exit 1
      end

    def install_gcc
      args = '--noconfirm --noprogressbar --needed'
      # zlib required by gcc, gdbm for older Rubies
      base_gcc  = %w[dlfcn make pkgconf libmangle-git tools-git gcc]
      base_ruby = %w[gdbm gmp libffi libyaml openssl ragel readline]

      pkgs = (base_gcc + base_ruby).unshift('').join " #{PKG_PRE}"

      # may not be needed, but...
      pacman_syuu

      exec_check "Updating the following #{PKG_PRE[0..-2]} packages:#{RST}\n" \
        "#{YEL}#{(base_gcc + base_ruby).join ' '}",
        "#{PACMAN} -S #{args} #{pkgs}"
    end

    # copies needed files from C:/msys64 to TEMP
    def copy_to_temp
      Dir.chdir TEMP do
        FileUtils.mkdir_p "msys64/#{SYNC}"
        FileUtils.mkdir_p "msys64/#{LOCAL}"
      end

      Dir.chdir "#{MSYS2_ROOT}/#{SYNC}" do
        FileUtils.cp "#{PKG_NAME}.db", "#{TAR_DIR}/#{SYNC}"
        FileUtils.cp "#{PKG_NAME}.db.sig", "#{TAR_DIR}/#{SYNC}"
      end

      ary = Dir.glob "#{PKG_PRE}*", base: "#{MSYS2_ROOT}/#{LOCAL}"

      local = "#{TAR_DIR}/#{LOCAL}"

      Dir.chdir "#{MSYS2_ROOT}/#{LOCAL}" do
        ary.each { |dir| FileUtils.copy_entry dir, "#{local}/#{dir}" }
      end

      FileUtils.copy_entry "#{MSYS2_ROOT}/#{PKG_NAME}", "#{TAR_DIR}/#{PKG_NAME}"
    end

    # removes files contained in 'share' folder to reduce 7z file size
    def clean_package
      share = "#{TAR_DIR}/#{PKG_NAME}/share"

      Dir.chdir "#{share}/doc" do
        ary = Dir.glob "*"
        ary.each { |dir| FileUtils.remove_dir dir }
      end

      Dir.chdir "#{share}/info" do
        ary = Dir.glob "*.gz"
        ary.each { |file| FileUtils.remove_file file }
      end

      Dir.chdir "#{share}/man" do
        ary = Dir.glob "**/*.gz"
        ary.each { |file| FileUtils.remove_file file }
      end

      # remove entries in 'files' file so updates won't log warnings
      Dir.chdir "#{TAR_DIR}/#{LOCAL}" do
        ary = Dir.glob "#{PKG_PRE}*/files"
        ary.each do |fn|
          File.open(fn, mode: 'r+b') { |f|
            str = f.read
            f.truncate 0
            f.rewind
            str.gsub!(/^#{PKG_NAME}\/share\/doc\/\S+\s*/m , '')
            str.gsub!(/^#{PKG_NAME}\/share\/info\/\S+\s*/m, '')
            str.gsub!(/^#{PKG_NAME}\/share\/man\/\S+\s*/m , '')
            f.write "#{str.strip}\n\n"
          }
        end
      end
    end

    def run
      current_pkgs = %x[#{PACMAN} -Q].split("\n").select { |l| l.start_with? PKG_PRE }

      install_gcc

      time = Time.now.utc.strftime '%Y-%m-%d %H:%M:%S UTC'

      updated_pkgs = %x[#{PACMAN} -Q].split("\n").select { |l| l.start_with? PKG_PRE }

      # log current packages
      log_array_2_column updated_pkgs.map { |el| el.sub PKG_PRE, ''}, 48,
        "Installed #{PKG_PRE[0..-2]} Packages"

      if current_pkgs == updated_pkgs
        STDOUT.syswrite "\n** No update to #{PKG_NAME} gcc tools needed **\n\n"
        exit 0
      else
        STDOUT.syswrite "\n#{GRN}** Creating and Uploading #{PKG_NAME} gcc tools 7z **#{RST}\n\n"
      end

      copy_to_temp

      clean_package

      # create 7z file
      STDOUT.syswrite "##[group]#{YEL}Create #{PKG_NAME} 7z file#{RST}\n"
      tar_path = "#{Dir.pwd}\\#{PKG_NAME}.7z".gsub '/', '\\'
      Dir.chdir TAR_DIR do
        exit 1 unless system "\"#{SEVEN}\" a #{tar_path}"
      end
      STDOUT.syswrite "##[endgroup]\n"

      upload_7z_update PKG_NAME, time
    end
  end
end

CreateMingwGCC.run
