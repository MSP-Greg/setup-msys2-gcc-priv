# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module Common
  # Generic constants
  USER_REPO    = ENV['GITHUB_REPOSITORY']
  TOKEN        = ENV['GITHUB_TOKEN']
  BUILD_NUMBER = ENV['GITHUB_RUN_NUMBER']

  GH_NAME = "#{USER_REPO}-actions"
  GH_API  = 'api.github.com'

  TEMP = ENV.fetch('RUNNER_TEMP') { ENV.fetch('RUNNER_WORKSPACE') { ENV['TEMP'] } }

  SEVEN = "C:\\Program Files\\7-Zip\\7z"

  DASH  = ENV['GITHUB_ACTIONS'] ? "\u2500".dup.force_encoding('utf-8') : 151.chr
  LINE  = DASH * 40
  GRN   = "\e[92m"
  YEL   = "\e[93m"
  RST   = "\e[0m"

  # Repo specific constants
  TAG = 'msys2-gcc-pkgs' # GitHub release tag
  MSYS2_ROOT = 'C:/msys64'
  PACMAN     = 'C:/msys64/usr/bin/pacman.exe'

  def gh_api_graphql(http, query)
    body = {}
    body["query"] = query
    response = nil

    req = Net::HTTP::Post.new '/gh_api_graphql'
    req['Authorization'] = "Bearer #{TOKEN}"
    req['Accept'] = 'application/json'
    req['Content-Type'] = 'application/json'
    req.body = JSON.generate body
    resp = http.request req

    if resp.code == '200'
      body = resp.body
      JSON.parse body, symbolize_names: true
    else
      STDOUT.syswrite "resp.code #{resp.code}\n"
    end
  end

  def gh_api_http
    Net::HTTP.start(GH_API, 443, :use_ssl => true) do |http|
      yield http
    end
  end

  def gh_api_v3_get(http, user_repo, suffix)
    req = Net::HTTP::Get.new "/repos/#{user_repo}/#{suffix}"
    req['User-Agent'] = GH_NAME
    req['Authorization'] = "token #{TOKEN}"
    req['Accept'] = 'application/vnd.github.v3+json'
    resp = http.request req
    resp.code == '200' ? JSON.parse(resp.body) : resp
  end

  def gh_api_v3_patch(http, user_repo, suffix, hsh)
    req = Net::HTTP::Patch.new "/repos/#{user_repo}/#{suffix}"
    req['User-Agent'] = GH_NAME
    req['Authorization'] = "token #{TOKEN}"
    req['Accept'] = 'application/vnd.github.v3+json'
    req['Content-Type'] = 'application/json; charset=utf-8'
    req.body = JSON.generate hsh

    resp = http.request req
    resp.code == '200' ? JSON.parse(resp.body) : resp
  end

  def upload_7z_update(pkg_name, time)
    # upload release asset using 'GitHub CLI'
    time_start = Process.clock_gettime Process::CLOCK_MONOTONIC
    unless system "gh release upload #{TAG} #{pkg_name}.7z --clobber"
      STDOUT.syswrite "\nUpload of new release asset failed!\n"
      exit 1
    end
    ttl_time = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - time_start).round 2
    STDOUT.syswrite "\n\nUpload 7z time: #{ttl_time} secs\n"

    # update package info in release notes
    gh_api_http do |http|
      resp_obj = gh_api_v3_get http, USER_REPO, "releases/tags/#{TAG}"
      body = resp_obj['body']
      id   = resp_obj['id']

      h = { 'body' => update_release_notes(body, pkg_name, time) }
      gh_api_v3_patch http, USER_REPO, "releases/#{id}", h
    end
  end

  def update_release_notes(old_body, name, time)
    old_body.sub(/(^\| +\*\*#{name}\*\* +\|).+/) {
      "#{$1} #{time} | #{BUILD_NUMBER.rjust 6} |"
    }
  end

  def pacman_syuu
    usr_bin = "#{MSYS2_ROOT}/usr/bin"

    exit 1 unless system "#{usr_bin}/sed -i 's/^CheckSpace/#CheckSpace/g' C:/msys64/etc/pacman.conf"

    exec_check 'Updating all installed packages', "#{PACMAN} -Syuu  --noconfirm"

    system 'taskkill /f /fi "MODULES eq msys-2.0.dll"'

    exec_check 'Updating all installed packages (2nd pass)', "#{PACMAN} -Syuu  --noconfirm"

    system 'taskkill /f /fi "MODULES eq msys-2.0.dll"'
  end

  # logs message and runs cmd, checking for error
  def exec_check(msg, cmd)
    STDOUT.syswrite "\n#{YEL}#{LINE} #{msg}#{RST}\n"
    exit 1 unless system cmd
  end

  def log_array_2_column(ary, wid, hdr)
    pad = (wid - hdr.length - 5)/2

    hdr_pad = pad > 0 ? "#{DASH * pad} #{hdr} #{DASH * pad}" : hdr

    STDOUT.syswrite "\n#{YEL}#{hdr_pad.ljust wid}#{hdr_pad}#{RST}\n"

    mod = ary.length % 2
    split  = ary.length/2
    offset = split + mod
    (0...split).each do
      |i| STDOUT.syswrite "#{ary[i].ljust wid}#{ary[i + offset]}\n"
    end
    STDOUT.syswrite "#{ary[split]}\n" if mod == 1
  end
end
