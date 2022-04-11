# frozen_string_literal: true

# Original code by MSP-Greg
# This script creates a 7z file using `vcpkg export` for use with Ruby mswin
# builds in GitHub Actions.

require 'fileutils'
require_relative 'common'

module CreateMswin
  class << self

    include Common

    PACKAGES = 'libffi libyaml openssl readline zlib'

    PKG_NAME = 'mswin'

    EXPORT_DIR = "#{TEMP}"

    VCPKG = ENV.fetch 'VCPKG_INSTALLATION_ROOT', 'C:/vcpkg'

    OPENSSL_PKG = 'packages/openssl_x64-windows'

    def generate_package_files
      ENV['VCPKG_ROOT'] = VCPKG
      Dir.chdir VCPKG do |d|
        update_info = %x(./vcpkg update)
        if update_info.include? 'No packages need updating'
          STDOUT.syswrite "\n#{GRN}No packages need updating#{RST}\n\n"
          exit 0
        else
          STDOUT.syswrite "\n#{update_info}\n\n"
        end

        exec_check "Upgrading #{PACKAGES}",
          "./vcpkg install #{PACKAGES} --triplet=x64-windows"

        exec_check "Exporting package files from vcpkg",
          "./vcpkg export --triplet=x64-windows #{PACKAGES} --raw --output=#{PKG_NAME} --output-dir=#{EXPORT_DIR}"
      end

      # Locations for vcpkg OpenSSL build
      # X509::DEFAULT_CERT_FILE      C:\vcpkg\packages\openssl_x64-windows/cert.pem
      # X509::DEFAULT_CERT_DIR       C:\vcpkg\packages\openssl_x64-windows/certs
      # Config::DEFAULT_CONFIG_FILE  C:\vcpkg\packages\openssl_x64-windows/openssl.cnf

      # make certs dir and copy openssl.cnf file
      ssl_path = "#{EXPORT_DIR}/#{PKG_NAME}/#{OPENSSL_PKG}"
      FileUtils.mkdir_p "#{ssl_path}/certs"
      IO.copy_stream "#{VCPKG}/#{OPENSSL_PKG}/openssl.cnf", "#{ssl_path}/openssl.cnf"
    end

    # vcpkg/installed/status contains a list of installed packages
    def generate_status_file
      status_path = 'installed/vcpkg/status'

      packages = File.binread("#{VCPKG}/#{status_path}").split "\n\n"

      needed = packages.select do |pkg|
        PACKAGES.include? pkg[/\APackage: (\S+)/, 1]
      end

      needed.sort_by! { |pkg| pkg[/\APackage: (\S+)/, 1] } << ''
      File.binwrite "#{EXPORT_DIR}/#{PKG_NAME}/#{status_path}",  needed.join("\n\n")
    end

    def run
      generate_package_files
      generate_status_file

      # create 7z archive file
      tar_path = "#{__dir__}\\#{PKG_NAME}.7z".gsub '/', '\\'

      Dir.chdir("#{EXPORT_DIR}/#{PKG_NAME}") do
        exec_check "Creating 7z file", "\"#{SEVEN}\" a #{tar_path}"
      end

      time = Time.now.utc.strftime '%Y-%m-%d %H:%M:%S UTC'
      upload_7z_update PKG_NAME, time
    end
  end
end

CreateMswin.run
