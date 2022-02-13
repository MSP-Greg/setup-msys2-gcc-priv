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

    TAR_DIR = "#{TEMP}/#{PKG_NAME}"

    VCPKG = ENV.fetch 'VCPKG_INSTALLATION_ROOT', 'C:/vcpkg'

    OPENSSL_PKG = 'packages/openssl_x64-windows'

    def generate_package
      ENV['VCPKG_ROOT'] = VCPKG
      Dir.chdir VCPKG do |d|
        
        if %x(./vcpkg update).include? 'No packages need updating'
          STDOUT.syswrite "\nNo packages need updating\n\n"
          exit 0
        end

        time_start = Process.clock_gettime Process::CLOCK_MONOTONIC
        exec_check "Upgrading #{PACKAGES}",
          "./vcpkg upgrade #{PACKAGES} --no-dry-run --triplet=x64-windows"

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) - time_start < 1
          STDOUT.syswrite "All packages are current\n\n"
          exit 0
        else
          exec_check "Creating export files",
            "./vcpkg export --triplet=x64-windows #{PACKAGES} --raw --output=#{PKG_NAME} --output-dir=#{TAR_DIR}"
        end
      end

      # Locations for vcpkg OpenSSL build
      # X509::DEFAULT_CERT_FILE      C:\vcpkg\packages\openssl_x64-windows/cert.pem
      # X509::DEFAULT_CERT_DIR       C:\vcpkg\packages\openssl_x64-windows/certs
      # Config::DEFAULT_CONFIG_FILE  C:\vcpkg\packages\openssl_x64-windows/openssl.cnf

      # make certs dir and copy openssl.cnf file

      ssl_path = "#{TAR_DIR}/#{PKG_NAME}/#{OPENSSL_PKG}"
      FileUtils.mkdir_p "#{ssl_path}/certs"

      IO.copy_stream "#{VCPKG}/#{OPENSSL_PKG}/openssl.cnf", "#{ssl_path}/openssl.cnf"

      tar_path = "#{__dir__}\\#{PKG_NAME}.7z".gsub '/', '\\'

      Dir.chdir("#{TAR_DIR}/#{PKG_NAME}") do
        exec_check "Creating 7z file",
          "\"#{SEVEN}\" a #{tar_path}"
      end
    end

    def run
      generate_package
      time = Time.now.utc.strftime '%Y-%m-%d %H:%M:%S UTC'
      upload_7z_update PKG_NAME, time
    end
  end
end

CreateMswin.run
