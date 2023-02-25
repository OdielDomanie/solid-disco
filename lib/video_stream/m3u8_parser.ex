defmodule VideoStream.M3U8Parser do
  @moduledoc false

  # https://developer.apple.com/documentation/http_live_streaming/example_playlists_for_http_live_streaming/live_playlist_sliding_window_construction

  defstruct [:version, :media_seq, :time, :segments]

  @type t :: %VideoStream.M3U8Parser{
          media_seq: integer,
          segments: [%{duration: float, path: binary}],
          time: DateTime.t(),
          version: integer
        }

  @spec parse(binary) :: VideoStream.M3U8Parser.t()
  def parse(contents) do
    %VideoStream.M3U8Parser{
      version: extract_version(contents),
      media_seq: extract_media_seq(contents),
      time: extract_time(contents),
      segments: extract_segments(contents)
    }
  end

  defp extract_version(contents) do
    Regex.named_captures(~r/^#EXT-X-VERSION:(?<version>\d+).*$/m, contents)
    |> Map.fetch!("version")
    |> String.to_integer()
  end

  defp extract_media_seq(contents) do
    Regex.named_captures(~r/^#EXT-X-MEDIA-SEQUENCE:(?<media_seq>\d+).*$/m, contents)
    |> Map.fetch!("media_seq")
    |> String.to_integer()
  end

  defp extract_time(contents) do
    {:ok, time, _} =
      Regex.named_captures(~r/^#EXT-X-PROGRAM-DATE-TIME:(?<time>\S+).*$/m, contents)
      |> Map.fetch!("time")
      |> DateTime.from_iso8601()

    time
  end

  @spec extract_segments(String.t()) :: [%{duration: float, path: String.t()}]
  defp extract_segments(contents) do
    segments_regex = ~r/^#EXTINF:([\d\.]+),.*\n*(.*)$/m
    segments = Regex.scan(segments_regex, contents)

    Enum.map(segments, fn [_, duration_str, seg_path] ->
      duration = String.to_float(duration_str)
      %{duration: duration, path: seg_path}
    end)
  end
end
