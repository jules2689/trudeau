require 'net/http'
require 'uri'
require 'json'
require 'date'

module Trudeau
  class PlaylistParser
    PLAYLIST_ID="PLeyJPHbRnGaYxLybblXjMbgiPdt6hhO7U"

    MISTAKEN_VIDEO_IDS = %w(
      f9sL4sfufEU
    )

    def initialize(token, num_videos)
      @token = token
      @num_videos = num_videos
    end

    def parse
      uri = URI.parse("https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=#{@num_videos}&playlistId=#{PLAYLIST_ID}&key=#{@token}")
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      parsed_resp = JSON.parse(response.body)
      if parsed_resp["items"].nil?
        raise parsed_resp.inspect
      end
      response = parse_items(parsed_resp)
      MISTAKEN_VIDEO_IDS.each do |id|
        response.merge!(video(id))
      end
      response.sort_by { |_, v| v[:sort_key] }.reverse
    end

    private

    def parse_items(parsed_resp)
      parsed_resp["items"].each_with_object({}) do |item, acc|
        id = if item["snippet"]["resourceId"]
          item["snippet"]["resourceId"]["videoId"]
        else
          item["id"]
        end
        acc[id] = {
          date: DateTime.parse(item["snippet"]["publishedAt"]).strftime('%Y-%m-%d'),
          sort_key: DateTime.parse(item["snippet"]["publishedAt"]),
          description: item["snippet"]["description"].lines.first,
          title: item["snippet"]["title"],
        }
      end
    end

    def video(id)
      uri = URI.parse("https://www.googleapis.com/youtube/v3/videos?id=#{id}&part=snippet&maxResults=#{@num_videos}&playlistId=#{PLAYLIST_ID}&key=#{@token}")
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      parsed_resp = JSON.parse(response.body)
      if parsed_resp["items"].nil?
        raise parsed_resp.inspect
      end
      parse_items(parsed_resp)
    end
  end
end
