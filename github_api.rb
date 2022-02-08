# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module GitHubAPI

  USER_REPO    = ENV['GITHUB_REPOSITORY']
  TOKEN        = ENV['GITHUB_TOKEN']
  BUILD_NUMBER = ENV['GITHUB_RUN_NUMBER']

  GH_NAME = "#{USER_REPO}-actions"

  TAG = 'msys2-gcc-pkgs'

  GH_API = 'api.github.com'

  def graphql(http, query)
    body = {}
    body["query"] = query
    response = nil

    req = Net::HTTP::Post.new '/graphql'
    req['Authorization'] = "Bearer #{TOKEN}"
    req['Accept'] = 'application/json'
    req['Content-Type'] = 'application/json'
    req.body = JSON.generate body
    resp = http.request req

    if resp.code == '200'
      body = resp.body
      JSON.parse body, symbolize_names: true
    else
      puts "resp.code #{resp.code}"
    end
  end

  def gh_api_http
    Net::HTTP.start(GH_API, 443, :use_ssl => true) do |http|
      yield http
    end
  end

  def v3_get(http, user_repo, suffix)
    req = Net::HTTP::Get.new "/repos/#{user_repo}/#{suffix}"
    req['User-Agent'] = GH_NAME
    req['Authorization'] = "token #{TOKEN}"
    req['Accept'] = 'application/vnd.github.v3+json'
    resp = http.request req
    resp.code == '200' ? JSON.parse(resp.body) : resp
  end

  def v3_patch(http, user_repo, suffix, hsh)
    req = Net::HTTP::Patch.new "/repos/#{user_repo}/#{suffix}"
    req['User-Agent'] = GH_NAME
    req['Authorization'] = "token #{TOKEN}"
    req['Accept'] = 'application/vnd.github.v3+json'
    req['Content-Type'] = 'application/json; charset=utf-8'
    req.body = JSON.generate hsh

    resp = http.request req
    resp.code == '200' ? JSON.parse(resp.body) : resp
  end
end
