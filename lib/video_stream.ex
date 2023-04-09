defmodule VideoStream do
  @moduledoc """
  Receive video segments from videos and live streams.

  The functions in this project may update the video info cache
  as side effects.
  """
  require Logger
  alias VideoStream.SegmentInfo
  alias VideoStream.HLS
  alias VideoStream.DashYT

  @type segment :: binary()
  @type segment_info :: SegmentInfo.t()

  @spec hls_stream(binary(), binary()) ::
          Enum.t({segment, segment_info})
  @doc """
  Takes a video stream webpage url, and a yt-dlp format string.
  Returns a tuple of stream info and a stream of video segments.
  """
  def hls_stream(vid_url, fmt_string) do
    with {:ok, m3u_url} <- YtDlp.fetch_playlist_url(vid_url, fmt_string) do
      HLS.vid_stream(m3u_url)
    end
  end

  @spec dash_segments(String.t(), String.t() | nil, {number(), number()}) ::
          [{:audio | :video | atom, Enum.t({segment, segment_info})}]
  def dash_segments(vid_url, format_string, {st, ed}, _source \\ :yt) when ed > st do
    body_limit = fn body_bin -> byte_size(body_bin) <= 1_000_000 end

    with {:ok, mpd_url} <- YtDlp.fetch_mpd(vid_url, format_string),
         {:ok, resp} <-
           Req.get(mpd_url,
             adapter: VideoStream.Utils.SafeReqAdapter.safe_adapter(body: body_limit)
           ),
         mpd when is_binary(mpd) <- resp.body do
      DashYT.segmentinfos_hack_yt(mpd, {st, ed})
      |> Enum.map(fn {type, seg_infos} -> {type, stream_from_seginfo(seg_infos)} end)
    end
  end

  def stream_from_seginfo(seginfos) do
    # seginfos = Enum.reverse(seginfos)

    Stream.resource(
      fn -> {seginfos, 0} end,
      &dl_seg/1,
      fn {_, count} -> Logger.info("Finished downloading #{count} segments.") end
    )
  end

  @spec dl_seg({list(segment_info()), count}) ::
          {
            {segment(), segment_info()},
            {list(segment_info()), count}
          }
          | {:halt, {[], count}}
        when count: pos_integer()
  defp dl_seg(seginfo_count)

  defp dl_seg({[%{url: url, expiry: expiry} = seginfo | rest], count}) do
    if expiry == nil || DateTime.compare(DateTime.utc_now(), expiry) == :lt do
      case Req.get(url) do
        {:ok, %{status: 200, body: body} = resp} when body != <<>> ->
          Logger.debug("Downloaded #{url}")
          {[{resp.body, seginfo}], {rest, count + 1}}

        {:ok, %{status: status, body: body}} when status != 200 or body == <<>> ->
          Logger.warning(
            "Could not download segment #{url} (expiry #{inspect(expiry)}), status: #{inspect(status)}, body: #{inspect(body)}"
          )

          dl_seg({rest, count})

        {:error, exc} ->
          Logger.warning(
            "Could not download segment #{url} (expiry #{inspect(expiry)}), exception: #{inspect(exc)}"
          )

          dl_seg({rest, count})
      end
    else
      Logger.info("Requested expired url: #{url} (expiry #{inspect(expiry)})")
      dl_seg({rest, count})
    end
  end

  defp dl_seg({[], count}), do: {:halt, {[], count}}
end
