require 'net/http'
require 'uri'
require 'json'
require 'date'

module Trudeau
  class PlaylistParser
    PLAYLIST_ID="PLeyJPHbRnGaYxLybblXjMbgiPdt6hhO7U"

    def initialize(token)
      @token = token
    end

    def parse
      uri = URI.parse("https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=50&playlistId=#{PLAYLIST_ID}&key=#{@token}")
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      parsed_resp = JSON.parse(response.body)
      if parsed_resp["items"].nil?
        raise parsed_resp.inspect
      end
      parsed_resp["items"].each_with_object({}) do |item, acc|
        acc[item["snippet"]["resourceId"]["videoId"]] = {
          date: DateTime.parse(item["snippet"]["publishedAt"]).strftime('%Y-%m-%d'),
          description: item["snippet"]["description"].lines.first,
          title: item["snippet"]["title"],
        }
      end
    end
  end
end
