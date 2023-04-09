defmodule VideoStream.HLS do
  @moduledoc """
  Process an HLS stream
  """
  alias VideoStream.HLS.Parser
  alias VideoStream.Utils.SafeReqAdapter

  @spec vid_stream(String.t()) :: Enum.t()
  @doc """
  Given the video url and the format string (eg. 301), returns a stream of
  segment data and metadata.
  """
  def vid_stream(m3u_url) do
    Stream.resource(
      fn -> m3u_url end,
      &next_segments/1,
      &stream_end/1
    )
  end

  @spec next_segments(String.t()) :: {[VideoStream.segment_info()], String.t()}
  def next_segments(m3u_url) do
    # An m3u8 playlist of an HLS stream is probably smaller then 100 kb;
    # just as a sanity check for security.
    body_limit = fn body_bin -> byte_size(body_bin) <= 100_000 end

    resp = Req.get!(m3u_url, adapter: SafeReqAdapter.safe_adapter(body: body_limit))

    segments =
      resp.body
      |> Parser.parse()
      |> Parser.segment_info()

    {
      for %{path: segment_path} = metadata <- segments do
        {
          Req.get!(segment_path).body,
          metadata
        }
      end,
      m3u_url
    }
  end

  # This is run both in success and failure
  defp stream_end(_), do: nil
end

# Youtube live segment (**.ts url) response.
#
# credo:disable-for-lines:34
# %Req.Response{
#   status: 200,
#   headers: [
#     {"last-modified", "Fri, 17 Feb 2023 14:00:13 GMT"},
#     {"date", "Fri, 17 Feb 2023 19:33:07 GMT"},
#     {"expires", "Fri, 17 Feb 2023 19:33:07 GMT"},
#     {"cache-control", "private, max-age=21298"},
#     {"content-type", "application/octet-stream"},
#     {"transfer-encoding", "chunked"},
#     {"connection", "keep-alive"},
#     {"alt-svc",
#      "h3=\":443\"; ma=2592000,h3-29=\":443\"; ma=2592000,h3-Q050=\":443\"; ma=2592000,h3-Q046=\":443\"; ma=2592000,h3-Q043=\":443\"; ma=2592000,quic=\":443\"; ma=2592000; v=\"46,43\""},
#     {"x-walltime-ms", "1676662387089"},
#     {"x-bandwidth-est", "2544426"},
#     {"x-bandwidth-est-comp", "2548129"},
#     {"x-bandwidth-est2", "2548129"},
#     {"x-bandwidth-app-limited", "false"},
#     {"x-bandwidth-est-app-limited", "false"},
#     {"x-bandwidth-est3", "1169495"},
#     {"x-head-time-sec", "19978"},
#     {"x-head-time-millis", "19978000"},
#     {"x-head-seqnum", "19978"},
#     {"vary", "Origin"},
#     {"cross-origin-resource-policy", "cross-origin"},
#     {"x-content-type-options", "nosniff"},
#     {"server", "gvs 1.0"}
#   ],
#   body: <<71, 64, 0, 48, 166, 0, 255, 255, 255, 255,
#     255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
#     255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
#     255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
#     255, 255, 255, 255, ...>>,
#   private: %{}
# }
