require 'net/http'
require 'uri'
require 'json'
require 'date'

class PlaylistParser
  PLAYLIST_ID="PLeyJPHbRnGaYxLybblXjMbgiPdt6hhO7U"

  def initialize(token)
    @token = token
  end

  def parse
    uri = URI.parse("https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=#{PLAYLIST_ID}&key=#{@token}")
    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/json"
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    parsed_resp = JSON.parse(response.body)
    parsed_resp["items"].each_with_object({}) do |item, acc|
      acc[item["snippet"]["resourceId"]["videoId"]] = {
        date: DateTime.parse(item["snippet"]["publishedAt"]).strftime('%Y-%m-%d'),
        title: item["snippet"]["title"],
      }
    end
  end
end
