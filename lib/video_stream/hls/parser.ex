defmodule VideoStream.HLS.Parser do
  @moduledoc """
  Parse information from HLS playlists.
  """

  # https://developer.apple.com/documentation/http_live_streaming/example_playlists_for_http_live_streaming/live_playlist_sliding_window_construction

  @type m3u_data :: %{
          seq: integer(),
          segments: [%{duration: float, path: binary}],
          time: DateTime.t(),
          version: integer()
        }

  @type segment :: %{
          path: String.t(),
          seq: integer(),
          time: DateTime.t(),
          duration: float(),
          expiry: DateTime.t() | nil | (error :: any())
        }

  @doc """
  Calculate and return a list of segment metadata.
  """
  @spec segment_info(m3u_data) :: [segment]
  def segment_info(m3u) do
    for segment <- m3u.segments, reduce: {[], {m3u.seq, m3u.time}} do
      {segments, {seq, time}} ->
        calced_segment = %{
          path: segment.path,
          seq: seq,
          time: time,
          duration: segment.duration,
          expiry: get_expiry(segment.path)
        }

        {[calced_segment | segments], {seq + 1, DateTime.add(time, segment.duration)}}
    end
  end

  # Parse the Youtube url to get the expiry time.
  defp get_expiry(url) do
    with [expiry_str] <- Regex.run(~r/(?<=\/expire\/)\d+(?=\/)/, url),
         {expiry_unix, ""} <- Integer.parse(expiry_str),
         {:ok, expiry_time} <- DateTime.from_unix(expiry_unix) do
      expiry_time
    end
  end

  @spec parse(binary) :: m3u_data()
  def parse(contents) do
    %{
      version: extract_version(contents),
      seq: extract_media_seq(contents),
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
